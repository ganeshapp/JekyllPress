import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/blog_post.dart';
import '../../../core/models/local_draft.dart';
import '../../../core/platform.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/drafts_provider.dart';
import '../../../core/providers/editor_provider.dart';
import '../../../core/providers/image_provider.dart';
import '../../../core/providers/posts_provider.dart';
import '../../../core/providers/publish_provider.dart';
import '../../../core/providers/queue_provider.dart';
import '../../../core/services/content_service.dart';
import '../../../core/services/github_upload_service.dart';
import '../../../core/services/publish_queue_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/frontmatter_parser.dart';
import '../../../core/utils/markdown_insert.dart';
import '../../../core/utils/youtube.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/external_url.dart';

class EditorScreen extends ConsumerStatefulWidget {
  final BlogPost? post;
  final LocalDraft? resumeDraft;

  const EditorScreen({super.key, this.post, this.resumeDraft});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  late TextEditingController _titleController;
  late TextEditingController _bodyController;
  final FocusNode _bodyFocusNode = FocusNode();
  final ScrollController _bodyScrollController = ScrollController();
  final UndoHistoryController _undoController = UndoHistoryController();

  bool get isNewPost => widget.post == null &&
      (widget.resumeDraft == null || !widget.resumeDraft!.isEditingExisting);
  bool _isInitialized = false;
  bool _isPickingImage = false;
  bool _isPickingVideo = false;

  // Last text pushed to the provider. TextEditingController notifies on
  // selection-only changes too - those must not rebuild or autosave.
  String _lastPushedTitle = '';
  String _lastPushedBody = '';

  // Auto-save debounce timer
  Timer? _autoSaveTimer;
  static const _autoSaveDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _titleController = TextEditingController();
    _bodyController = TextEditingController();

    _tabController.addListener(_onTabChanged);

    // Register lifecycle observer for saving on background
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;

      // Set up text controller values immediately (no provider modification)
      if (widget.resumeDraft != null) {
        // Resuming a draft - use draft content
        _titleController.text = widget.resumeDraft!.title;
        _bodyController.text = widget.resumeDraft!.bodyContent;
      } else if (widget.post != null) {
        // Editing existing post
        _titleController.text = widget.post!.title;
        _bodyController.text = widget.post!.bodyContent;
      }

      // Loaded content matches what the provider gets initialized with
      _lastPushedTitle = _titleController.text;
      _lastPushedBody = _bodyController.text;

      // Add listeners
      _titleController.addListener(_onTitleChanged);
      _bodyController.addListener(_onBodyChanged);

      // Delay provider modification until after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeEditorProvider();
        _initializeDraftProvider();
      });
    }
  }

  void _initializeEditorProvider() {
    if (!mounted) return;

    final controller = ref.read(editorControllerProvider.notifier);

    // Config front matter defaults pre-fill the Post settings sheet for
    // brand-new posts (the user can clear them there)
    final configState = ref.read(configNotifierProvider);
    final config = configState is ConfigLoaded ? configState.config : null;

    if (widget.resumeDraft != null) {
      // Resuming a draft - the draft content is the baseline, so an
      // untouched resumed draft doesn't show as "Editing"
      controller.initializeWithDraft(
        title: widget.resumeDraft!.title,
        bodyContent: widget.resumeDraft!.bodyContent,
        originalPost: widget.resumeDraft!.isEditingExisting ? widget.post : null,
        defaultLayout: config?.defaultLayout,
        defaultCategories: config?.defaultCategories ?? const [],
        defaultTags: config?.defaultTags ?? const [],
      );
    } else if (widget.post != null) {
      controller.initializeWithPost(widget.post!);
    } else {
      controller.initializeNewPost(
        defaultLayout: config?.defaultLayout,
        defaultCategories: config?.defaultCategories ?? const [],
        defaultTags: config?.defaultTags ?? const [],
      );
    }
  }

  void _initializeDraftProvider() {
    if (!mounted) return;

    final draftNotifier = ref.read(currentDraftNotifierProvider.notifier);

    if (widget.resumeDraft != null) {
      // Resuming an existing draft
      draftNotifier.initializeWithDraft(widget.resumeDraft!);
    } else if (widget.post != null) {
      // Editing existing post - check for existing draft
      draftNotifier.initializeForExistingPost(widget.post!);
    } else {
      // New post - create new draft
      draftNotifier.initializeNewDraft();
    }
  }

  /// Handle app lifecycle changes - save on background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // App is going to background - save immediately
      _saveImmediately();
    }
  }

  /// Save draft immediately (bypasses debounce).
  /// Returns true when the draft was actually persisted.
  Future<bool> _saveImmediately() async {
    _autoSaveTimer?.cancel();

    final draftNotifier = ref.read(currentDraftNotifierProvider.notifier);
    return draftNotifier.forceSave(
      title: _titleController.text,
      bodyContent: _bodyController.text,
    );
  }

  /// Trigger debounced auto-save
  void _triggerAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(_autoSaveDelay, () {
      if (mounted) {
        final draftNotifier = ref.read(currentDraftNotifierProvider.notifier);
        draftNotifier.updateAndSave(
          title: _titleController.text,
          bodyContent: _bodyController.text,
        );
      }
    });
  }

  void _onTitleChanged() {
    final text = _titleController.text;
    if (text == _lastPushedTitle) return;
    _lastPushedTitle = text;
    ref.read(editorControllerProvider.notifier).updateTitle(text);
    _triggerAutoSave();
  }

  void _onBodyChanged() {
    final text = _bodyController.text;
    if (text == _lastPushedBody) return;
    _lastPushedBody = text;
    ref.read(editorControllerProvider.notifier).updateBody(text);
    _triggerAutoSave();
  }

  void _onTabChanged() {
    // Unfocus text fields when switching to preview
    if (_tabController.index == 1) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Cancel auto-save timer
    _autoSaveTimer?.cancel();

    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _titleController.removeListener(_onTitleChanged);
    _bodyController.removeListener(_onBodyChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocusNode.dispose();
    _bodyScrollController.dispose();
    _undoController.dispose();
    super.dispose();
  }

  /// Handle back navigation - auto-save to drafts, no discard prompt
  Future<void> _handleBack() async {
    // Cancel any pending auto-save
    _autoSaveTimer?.cancel();

    // Save current state to drafts before closing
    final saved = await _saveImmediately();

    // Clear editor state
    ref.read(editorControllerProvider.notifier).clear();
    ref.read(currentDraftNotifierProvider.notifier).clear();

    if (mounted) {
      // Only claim a save when the draft was actually persisted
      if (saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.save_rounded, color: context.appColors.success, size: 18),
                const SizedBox(width: 12),
                Text(context.l10n.draftSavedSnack),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
      Navigator.of(context).pop();
    }
  }

  bool _isPublishing = false;

  /// Publish the post. For NEW posts, [asDraft] saves to the remote
  /// Jekyll drafts dir instead (Publish button's overflow menu).
  Future<void> _handleSave({bool asDraft = false}) async {
    // Cancel pending auto-save so it can't race the publish
    _autoSaveTimer?.cancel();

    // Read directly from the controllers - they are the source of truth
    final title = _titleController.text;
    final bodyContent = _bodyController.text;

    if (title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.pleaseEnterTitle),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_isPublishing) return;
    setState(() => _isPublishing = true);

    HapticFeedback.mediumImpact();

    try {
      // Media referenced in the body must be settled (or explicitly
      // overridden) before the post goes live
      if (!await _ensureMediaUploaded(bodyContent)) return;
      if (!mounted) return;

      // Don't fire a doomed request when the device is clearly offline -
      // offer the queue up front
      if (await _isDefinitelyOffline()) {
        if (mounted) await _handleOfflinePublish(asDraft: asDraft);
        return;
      }
      if (!mounted) return;

      final publishNotifier = ref.read(publishNotifierProvider.notifier);
      final editorState = ref.read(editorControllerProvider);
      // A conflict 'Keep both' reload swaps the session onto the fresh
      // remote post, so prefer the editor's originalPost over widget.post
      final originalPost = editorState.originalPost ?? widget.post;

      // Loop so the conflict dialog's 'Overwrite' can re-run the publish
      // with the force flag set
      var force = false;
      while (true) {
        bool success;
        if (isNewPost) {
          // Create new post - the Post settings sheet values drive the
          // front matter ('' / empty list = omit the key)
          success = await publishNotifier.publishNewPost(
            title: title,
            bodyContent: bodyContent,
            asDraft: asDraft,
            publishDate: editorState.publishDate,
            layout: editorState.layout,
            categories: editorState.categories,
            tags: editorState.tags,
          );
        } else {
          // Update existing post. Untouched settings pass null so the
          // original front matter is preserved byte-exact; edited settings
          // are merged with unmodeled fields passing through verbatim.
          final settingsEdited = editorState.frontmatterEdited;
          success = await publishNotifier.publishUpdate(
            originalPost: originalPost!,
            newBodyContent: bodyContent,
            publishDate: editorState.publishDate,
            layout: settingsEdited ? editorState.layout : null,
            categories: settingsEdited ? editorState.categories : null,
            tags: settingsEdited ? editorState.tags : null,
            force: force,
          );
        }
        if (!mounted) return;

        if (success) {
          // This publish supersedes any queued copy of the same draft
          // (the user may have reopened a queued post's safety draft from
          // the Drafts tab) - drop it so the queue can't publish a
          // duplicate when connectivity returns
          final publishedDraftId = ref
              .read(currentDraftNotifierProvider.notifier)
              .currentDraft
              ?.id;
          if (publishedDraftId != null) {
            await ref
                .read(publishQueueNotifierProvider.notifier)
                .removeItemsForDraft(publishedDraftId);
          }
          if (!mounted) return;

          // Clear editor state and delete draft
          ref.read(editorControllerProvider.notifier).clear();
          await ref
              .read(currentDraftNotifierProvider.notifier)
              .clearAfterPublish();
          if (!mounted) return;

          // Refresh posts list and drafts
          ref.read(postsNotifierProvider.notifier).refresh();
          ref.read(draftsNotifierProvider.notifier).refresh();

          // Show success message, with a View action when the post has a
          // public URL on the configured site
          final publishState = ref.read(publishNotifierProvider);
          String message = context.l10n.postPublishedSuccess;
          String? viewUrl;
          if (publishState is PublishSucceeded) {
            viewUrl = publishState.publicUrl;
            message = asDraft
                ? context.l10n.draftSavedToGitHub(publishState.filename)
                : isNewPost
                    ? context.l10n.postCreated(publishState.filename)
                    : context.l10n.postUpdatedSuccess;
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: context.appColors.success, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(message)),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: viewUrl != null
                  ? const Duration(seconds: 6)
                  : const Duration(seconds: 4),
              action: viewUrl != null
                  ? SnackBarAction(
                      label: context.l10n.commonView,
                      textColor: context.colorScheme.primary,
                      onPressed: () => _launchExternal(viewUrl!),
                    )
                  : null,
            ),
          );

          // Reset publish state and navigate back
          publishNotifier.reset();
          Navigator.of(context).pop();
          return;
        }

        // Failure: typed recovery flows first, generic snackbar otherwise
        final publishState = ref.read(publishNotifierProvider);
        final failure = publishState is PublishFailed ? publishState : null;

        if (failure != null &&
            failure.kind == PublishErrorKind.conflict &&
            !isNewPost) {
          final choice = await _showConflictDialog();
          if (!mounted) return;
          if (choice == _ConflictChoice.overwrite) {
            force = true;
            continue;
          }
          if (choice == _ConflictChoice.keepBoth) {
            await _keepBothVersions(originalPost!);
          }
          return; // Cancel / dismissed
        }

        if (failure != null && failure.kind == PublishErrorKind.offline) {
          await _handleOfflinePublish(asDraft: asDraft);
          return;
        }

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: context.colorScheme.error, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    failure?.error ?? context.l10n.failedToPublishGeneric,
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }

  /// Open [url] in the external browser (best-effort, no context needed
  /// after pop - errors are silently ignored)
  void _launchExternal(String url) => openExternalUrlUnawaited(url);

  /// True only when connectivity_plus is POSITIVE there is no network.
  /// Any uncertainty returns false and lets the request itself decide.
  Future<bool> _isDefinitelyOffline() async {
    try {
      final results =
          await ref.read(connectivityProvider).checkConnectivity();
      return results.isNotEmpty &&
          results.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  /// Offline publish flow: offer to queue the post so it publishes
  /// automatically when the connection returns
  Future<void> _handleOfflinePublish({required bool asDraft}) async {
    final choice = await _showOfflineDialog();
    if (!mounted) return;

    switch (choice) {
      case _OfflineChoice.queue:
        await _queuePublish(asDraft: asDraft);
      case _OfflineChoice.discard:
        // Explicitly chosen over queueing and keep-editing: the draft
        // goes too
        await ref.read(currentDraftNotifierProvider.notifier).discardDraft();
        if (!mounted) return;
        ref.read(editorControllerProvider.notifier).clear();
        Navigator.of(context).pop();
      default:
        return; // Keep editing / dismissed
    }
  }

  /// Queue the publish and close the editor like a successful publish.
  /// The local draft is KEPT as a safety net; its id rides on the queue
  /// item so both are cleaned up when the queued publish succeeds.
  Future<void> _queuePublish({required bool asDraft}) async {
    // Make sure the safety-net draft holds the latest content
    await _saveImmediately();
    if (!mounted) return;

    final editorState = ref.read(editorControllerProvider);
    final originalPost = editorState.originalPost ?? widget.post;
    final settingsEdited = editorState.frontmatterEdited;
    final draftId =
        ref.read(currentDraftNotifierProvider.notifier).currentDraft?.id;

    // Capture exactly what _handleSave would have passed to the publish
    // notifier (creates always send the sheet values, updates only send
    // edited ones so untouched front matter stays byte-exact)
    final item = QueuedPublish(
      id: 'queued_${DateTime.now().millisecondsSinceEpoch}',
      type: isNewPost ? QueuedPublish.typeCreate : QueuedPublish.typeUpdate,
      title: _titleController.text,
      bodyContent: _bodyController.text,
      asDraft: asDraft,
      createdAt: DateTime.now(),
      publishDate: editorState.publishDate,
      layout: isNewPost
          ? editorState.layout
          : (settingsEdited ? editorState.layout : null),
      categories: isNewPost
          ? editorState.categories
          : (settingsEdited ? editorState.categories : null),
      tags: isNewPost
          ? editorState.tags
          : (settingsEdited ? editorState.tags : null),
      originalPath: originalPost?.filePath,
      originalSha: originalPost?.sha,
      originalFileName: originalPost?.fileName,
      originalDate: originalPost?.date,
      originalFrontmatter: originalPost?.rawFrontmatter,
      safetyDraftId: draftId,
    );
    final queueNotifier = ref.read(publishQueueNotifierProvider.notifier);
    // Re-queuing the same draft REPLACES its previous queue entry -
    // otherwise reopening a queued draft and queueing again would
    // publish the post twice when connectivity returns
    if (draftId != null) {
      await queueNotifier.removeItemsForDraft(draftId);
    }
    await queueNotifier.enqueue(item);
    if (!mounted) return;

    // Close like a successful publish, but KEEP the local draft
    ref.read(editorControllerProvider.notifier).clear();
    ref.read(currentDraftNotifierProvider.notifier).clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.schedule_send_rounded,
                color: context.colorScheme.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(context.l10n.queuedWillPublishWhenOnline)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<_OfflineChoice?> _showOfflineDialog() {
    return showDialog<_OfflineChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.offlineDialogTitle),
        content: Text(context.l10n.offlineDialogBody),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _OfflineChoice.keepEditing),
            child: Text(context.l10n.keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _OfflineChoice.discard),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.error,
            ),
            child: Text(context.l10n.discardAction),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _OfflineChoice.queue),
            child: Text(context.l10n.queueAndPublishWhenOnline),
          ),
        ],
      ),
    );
  }

  Future<_ConflictChoice?> _showConflictDialog() {
    return showDialog<_ConflictChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.conflictDialogTitle),
        content: Text(context.l10n.conflictDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ConflictChoice.keepBoth),
            child: Text(context.l10n.keepBoth),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _ConflictChoice.overwrite),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.error,
            ),
            child: Text(context.l10n.overwriteWithMyVersion),
          ),
        ],
      ),
    );
  }

  /// Conflict 'Keep both': the current editor content is saved as its
  /// own local draft, then the remote version is loaded into the editor
  /// so nothing is lost on either side.
  Future<void> _keepBothVersions(BlogPost originalPost) async {
    _autoSaveTimer?.cancel();

    // 1. My version becomes a standalone local draft
    final myDraft = LocalDraft.newDraft(
      id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text,
      bodyContent: _bodyController.text,
    );
    await ref.read(draftsNotifierProvider.notifier).saveDraft(myDraft);
    if (!mounted) return;

    // 2. Fetch the remote version (content + current sha)
    final configState = ref.read(configNotifierProvider);
    final config = configState is ConfigLoaded ? configState.config : null;
    final path = originalPost.filePath ??
        (originalPost.fileName != null && config != null
            ? '${ContentService.cleanDir(config.postsPath)}/${originalPost.fileName}'
            : null);
    if (config == null || path == null) {
      _showMediaGateSnack(context.l10n.savedButRemoteNotLocated);
      return;
    }

    BlogPost fresh;
    try {
      final content = await ref
          .read(contentServiceProvider)
          .fetchFileContent(config, path);
      final sha = await ref
          .read(githubUploadServiceProvider)
          .fetchCurrentSha(config: config, path: path);
      final parsed = FrontmatterParser.parse(content);
      fresh = originalPost.copyWith(
        sha: sha,
        title: parsed.title,
        date: parsed.date,
        rawFrontmatter: parsed.rawFrontmatter,
        bodyContent: parsed.bodyContent,
      );
    } catch (e) {
      if (mounted) {
        _showMediaGateSnack(context.l10n.savedButRemoteNotLoaded('$e'));
      }
      return;
    }
    if (!mounted) return;

    // 3. Update the cache and swap this editing session onto the remote
    // version. The edit-draft held my version, which now lives in
    // [myDraft] - drop it so it doesn't resurface as diverging edits.
    await ref.read(postsNotifierProvider.notifier).updatePost(fresh);
    await ref.read(currentDraftNotifierProvider.notifier).clearAfterPublish();
    if (!mounted) return;

    _titleController.text = fresh.title;
    _bodyController.text = fresh.bodyContent;
    ref.read(editorControllerProvider.notifier).initializeWithPost(fresh);
    ref
        .read(currentDraftNotifierProvider.notifier)
        .initializeForExistingPost(fresh);
    // Setting the controllers fired the change listeners, which armed the
    // autosave debounce - the fresh content IS the baseline, so an
    // autosave now would only persist a no-op edit draft
    _autoSaveTimer?.cancel();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.savedNowShowingRemote),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Gate publishing on media uploads: media filenames referenced in
  /// [bodyContent] that are still uploading or have failed get a dialog
  /// (wait / retry / publish anyway / cancel). Returns true to proceed.
  Future<bool> _ensureMediaUploaded(String bodyContent) async {
    while (true) {
      final statuses = ref.read(imageManagerProvider);
      final inBody = statuses.entries
          .where((entry) => bodyContent.contains(entry.key))
          .toList();
      final pending = [
        for (final entry in inBody)
          if (!entry.value.isUploaded && entry.value.error == null) entry.key,
      ];
      final failed = [
        for (final entry in inBody)
          if (entry.value.error != null) entry.key,
      ];

      if (pending.isEmpty && failed.isEmpty) return true;
      if (!mounted) return false;

      if (pending.isNotEmpty) {
        final choice = await _showPendingUploadsDialog(pending.length);
        switch (choice) {
          case _MediaGateChoice.publishAnyway:
            return true;
          case _MediaGateChoice.wait:
            if (!await _waitForUploads(pending)) {
              if (!mounted) return false;
              _showMediaGateSnack(context.l10n.uploadsTakingTooLong);
              return false;
            }
            continue; // Re-check: a waited upload may have failed
          default:
            return false; // Cancel / dismissed
        }
      }

      // Only failures left
      final choice = await _showFailedUploadsDialog(failed);
      switch (choice) {
        case _MediaGateChoice.publishAnyway:
          return true;
        case _MediaGateChoice.retry:
          final imageManager = ref.read(imageManagerProvider.notifier);
          final retries = [
            for (final filename in failed) imageManager.retryUpload(filename),
          ];
          if (!await _showUploadWaitDialog(Future.wait(retries))) {
            if (!mounted) return false;
            _showMediaGateSnack(context.l10n.uploadsTakingTooLong);
            return false;
          }
          continue; // Re-check: retries may have failed again
        default:
          return false; // Cancel / dismissed
      }
    }
  }

  /// Wait (up to 60s, behind a blocking dialog) until every filename in
  /// [filenames] is settled: uploaded or failed. True when all settled.
  Future<bool> _waitForUploads(List<String> filenames) {
    bool settled(Map<String, ImageUploadStatus> statuses) =>
        filenames.every((filename) {
          final status = statuses[filename];
          return status == null || status.isUploaded || status.error != null;
        });

    if (settled(ref.read(imageManagerProvider))) {
      return Future.value(true);
    }

    final completer = Completer<void>();
    final subscription = ref.listenManual(imageManagerProvider, (_, next) {
      if (!completer.isCompleted && settled(next)) {
        completer.complete();
      }
    });

    return _showUploadWaitDialog(completer.future)
        .whenComplete(subscription.close);
  }

  /// Show a blocking progress dialog until [operation] completes or 60s
  /// elapse. Returns true when it completed in time.
  Future<bool> _showUploadWaitDialog(Future<void> operation) async {
    BuildContext? dialogContext;
    // Not awaited - dismissed programmatically below
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        dialogContext = context;
        return AlertDialog(
          content: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: context.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(context.l10n.waitingForUploads)),
            ],
          ),
        );
      },
    );

    var completed = true;
    try {
      await operation.timeout(const Duration(seconds: 60));
    } on TimeoutException {
      completed = false;
    } catch (_) {
      // Upload failures surface through the status map, not here
    }

    // The operation can settle before the dialog's first frame - give
    // the route a beat to build so it can be dismissed
    if (dialogContext == null) {
      await Future<void>.delayed(Duration.zero);
    }
    if (dialogContext != null && dialogContext!.mounted) {
      Navigator.of(dialogContext!).pop();
    }
    return completed;
  }

  Future<_MediaGateChoice?> _showPendingUploadsDialog(int count) {
    return showDialog<_MediaGateChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.mediaStillUploadingTitle),
        content: Text(context.l10n.pendingUploadsBody(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _MediaGateChoice.publishAnyway),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.error,
            ),
            child: Text(context.l10n.publishAnyway),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _MediaGateChoice.wait),
            child: Text(context.l10n.waitAction),
          ),
        ],
      ),
    );
  }

  Future<_MediaGateChoice?> _showFailedUploadsDialog(List<String> failed) {
    return showDialog<_MediaGateChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.mediaUploadsFailedTitle),
        content: Text(
          context.l10n.failedUploadsBody(
            failed.map((filename) => '• $filename').join('\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _MediaGateChoice.publishAnyway),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.error,
            ),
            child: Text(context.l10n.publishAnyway),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _MediaGateChoice.retry),
            child: Text(context.l10n.retryUploads),
          ),
        ],
      ),
    );
  }

  void _showMediaGateSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Let the user choose where the image comes from.
  /// Returns true for camera, false for gallery, null when dismissed.
  Future<bool?> _showImageSourceSheet() {
    return showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.photo_library_rounded,
                color: context.colorScheme.primary,
              ),
              title: Text(
                context.l10n.galleryOption,
                style: TextStyle(color: context.colorScheme.onSurface),
              ),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_camera_rounded,
                color: context.colorScheme.primary,
              ),
              title: Text(
                context.l10n.cameraOption,
                style: TextStyle(color: context.colorScheme.onSurface),
              ),
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAddImage() async {
    if (_isPickingImage) return;

    // Gallery or camera (video stays gallery-only); desktop has no camera
    final fromCamera = ref.read(imageServiceProvider).canUseCamera
        ? await _showImageSourceSheet()
        : false;
    if (fromCamera == null || !mounted) return;

    setState(() => _isPickingImage = true);

    try {
      final imageManager = ref.read(imageManagerProvider.notifier);
      final filename = await imageManager.pickImage(fromCamera: fromCamera);

      if (filename != null && mounted) {
        final markdown = imageManager.generateMarkdownImage(filename);
        _insertTextAtCursor('\n$markdown\n');

        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(context.l10n.uploadingImage),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Background is overridden: take the foreground from onError so
            // the message stays readable in both themes
            content: Text(
              context.l10n.failedToAddImage('$e'),
              style: TextStyle(color: context.colorScheme.onError),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingImage = false);
      }
    }
  }

  Future<void> _handleAddVideo() async {
    if (_isPickingVideo) return;

    setState(() => _isPickingVideo = true);

    try {
      final imageManager = ref.read(imageManagerProvider.notifier);
      final filename = await imageManager.pickVideo(
        onCompressionStart: () {
          // Compression can take a while - keep the user informed while
          // the toolbar button shows its spinner
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(context.l10n.compressingVideo),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(minutes: 2),
            ),
          );
        },
      );

      if (mounted) {
        // Replace the long-lived compressing snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (filename != null && mounted) {
        _insertTextAtCursor(
          imageManager.generateVideoEmbed(filename),
          asBlock: true,
        );

        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(context.l10n.uploadingVideo),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Size-limit / compression errors carry their own message.
            // Background is overridden, so pair it with onError.
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: TextStyle(color: context.colorScheme.onError),
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingVideo = false);
      }
    }
  }

  /// Ask for a YouTube link and insert the player embed at the cursor
  Future<void> _handleAddYouTube() async {
    var url = '';
    final video = await showDialog<YouTubeVideo>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final parsed = parseYouTubeUrl(url);
          final insert =
              parsed == null ? null : () => Navigator.pop(context, parsed);
          return AlertDialog(
            title: Text(context.l10n.addYouTubeTitle),
            content: TextField(
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: context.l10n.youTubeLinkHint,
                errorText: parsed == null && url.trim().isNotEmpty
                    ? context.l10n.notAYouTubeLink
                    : null,
              ),
              onChanged: (value) => setDialogState(() => url = value),
              onSubmitted: (_) => insert?.call(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.commonCancel),
              ),
              TextButton(
                onPressed: insert,
                child: Text(context.l10n.insertAction),
              ),
            ],
          );
        },
      ),
    );
    if (video == null || !mounted) return;
    _insertTextAtCursor(youTubeEmbed(video), asBlock: true);
    HapticFeedback.mediumImpact();
  }

  /// Force a plain tap to place the caret instead of extending a selection.
  ///
  /// Flutter treats a tap as "extend selection to here" whenever it believes
  /// Shift is held. On some devices that state gets stuck - a paired
  /// Bluetooth keyboard, or an IME that emits a Shift press without a
  /// matching release - and then every tap in a long post selects everything
  /// between the old caret and the tap. There is no shift-tap gesture to
  /// preserve on a touch-only writing surface, so a single tap always
  /// collapses to where the user actually tapped (the extent).
  ///
  /// Runs after the framework has set the selection. Double-tap-to-select-word
  /// is unaffected: [TextField.onTap] only fires on the first tap of a series.
  void _collapseCaretAfterTap() {
    final selection = _bodyController.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    _bodyController.selection =
        TextSelection.collapsed(offset: selection.extentOffset);
  }

  /// Insert [text] at the cursor, replacing any selection. [asBlock] pads it
  /// with blank lines (see [padAsBlock]) for raw-HTML embeds.
  void _insertTextAtCursor(String text, {bool asBlock = false}) {
    final value = _bodyController.value;
    final selection = value.selection;

    // Replace an active selection instead of splicing into it.
    // No valid selection (field never focused) means append at the end
    // and scroll there.
    final int start;
    final int end;
    if (selection.isValid) {
      start = selection.start;
      end = selection.end;
    } else {
      start = value.text.length;
      end = value.text.length;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _bodyScrollController.hasClients) {
          _bodyScrollController.jumpTo(
            _bodyScrollController.position.maxScrollExtent,
          );
        }
      });
    }

    if (asBlock) {
      text = padAsBlock(
        text,
        before: value.text.substring(0, start),
        after: value.text.substring(end),
      );
    }
    final newText = value.text.replaceRange(start, end, text);

    // Set text + selection atomically so listeners fire once with a
    // valid selection
    _bodyController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + text.length),
    );
    _bodyFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: Container(
          decoration: AppTheme.backgroundGradient(context),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                _buildTabBar(),
                Expanded(
                  // IndexedStack keeps both tabs alive so Write scroll
                  // position, undo history, and Preview scroll survive
                  // tab switches
                  child: ListenableBuilder(
                    listenable: _tabController,
                    builder: (context, _) {
                      return IndexedStack(
                        index: _tabController.index,
                        children: [
                          _buildWriteTab(),
                          _buildPreviewTab(),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            color: context.colorScheme.onSurfaceVariant,
            tooltip: context.l10n.commonBack,
            onPressed: _handleBack,
          ),
          Expanded(
            child: Text(
              isNewPost
                  ? context.l10n.newPostAction
                  : context.l10n.editPostTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          // Save status indicator - watches providers locally so the
          // whole screen doesn't rebuild on every status change
          Consumer(
            builder: (context, ref, _) {
              final saveStatus = ref.watch(currentDraftNotifierProvider);
              final hasUnsavedChanges = ref.watch(
                editorControllerProvider.select((s) => s.hasUnsavedChanges),
              );
              return _buildSaveStatusIndicator(saveStatus, hasUnsavedChanges);
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            color: context.colorScheme.onSurfaceVariant,
            tooltip: context.l10n.postSettingsLabel,
            onPressed: _showPostSettings,
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _isPublishing ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: _isPublishing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colorScheme.onPrimary,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.publish_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(context.l10n.publishAction),
                    ],
                  ),
          ),
          // Alternative publish targets for NEW posts (kept adjacent to,
          // not inside, the Publish button)
          if (isNewPost)
            PopupMenuButton<String>(
              enabled: !_isPublishing,
              tooltip: context.l10n.morePublishOptionsTooltip,
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: context.colorScheme.onSurfaceVariant,
              ),
              onSelected: (value) {
                if (value == 'draft') _handleSave(asDraft: true);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'draft',
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_upload_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text(context.l10n.saveAsDraftOnGitHub),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSaveStatusIndicator(DraftSaveStatus status, bool hasUnsavedChanges) {
    IconData icon;
    String text;
    Color color;
    bool showSpinner = false;

    switch (status) {
      case DraftSaveStatus.saving:
        icon = Icons.sync_rounded;
        text = context.l10n.statusSaving;
        color = context.colorScheme.primary;
        showSpinner = true;
        break;
      case DraftSaveStatus.saved:
        icon = Icons.check_circle_rounded;
        text = context.l10n.statusSaved;
        color = context.appColors.success;
        break;
      case DraftSaveStatus.error:
        icon = Icons.error_outline_rounded;
        text = context.l10n.statusError;
        color = context.colorScheme.error;
        break;
      case DraftSaveStatus.idle:
        if (hasUnsavedChanges) {
          icon = Icons.edit_rounded;
          text = context.l10n.editingStatus;
          color = context.colorScheme.onSurfaceVariant;
        } else {
          // Nothing to show when idle and no changes
          return const SizedBox.shrink();
        }
        break;
    }

    return Semantics(
      label: context.l10n.draftStatusSemantics(text),
      liveRegion: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(25),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showSpinner)
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: color,
                ),
              )
            else
              Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outline.withAlpha(80),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: context.colorScheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: context.colorScheme.onPrimary,
        unselectedLabelColor: context.colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_rounded, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.tabWrite),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.visibility_rounded, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.tabPreview),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title field
          Text(
            context.l10n.titleLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          Container(
            decoration: AppTheme.cardGlow(context),
            child: TextField(
              controller: _titleController,
              enabled: isNewPost,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _bodyFocusNode.requestFocus(),
              spellCheckConfiguration: const SpellCheckConfiguration(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isNewPost
                    ? context.colorScheme.onSurface
                    : context.colorScheme.onSurfaceVariant,
              ),
              decoration: InputDecoration(
                hintText: context.l10n.enterPostTitleHint,
                filled: true,
                fillColor: isNewPost
                    ? context.colorScheme.surfaceContainer
                    : context.colorScheme.surfaceContainer.withAlpha(150),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: context.colorScheme.outline.withAlpha(80),
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: context.colorScheme.outline.withAlpha(40),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: context.colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 16,
                ),
                suffixIcon: !isNewPost
                    ? Tooltip(
                        message: context.l10n.titleLockedTooltip,
                        child: Icon(
                          Icons.lock_rounded,
                          size: 18,
                          color: context.colorScheme.onSurfaceVariant.withAlpha(150),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          if (!isNewPost) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.titleLockedNote,
              style: TextStyle(
                fontSize: 12,
                color: context.colorScheme.onSurfaceVariant.withAlpha(150),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Toolbar row
          _buildToolbar(),
          const SizedBox(height: 8),

          // Body field - fills the remaining space and scrolls internally,
          // so a drag scrolls the editor instead of extending a selection
          Expanded(
            child: Container(
              decoration: AppTheme.cardGlow(context),
              child: TextField(
                controller: _bodyController,
                focusNode: _bodyFocusNode,
                scrollController: _bodyScrollController,
                undoController: _undoController,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                onTap: _collapseCaretAfterTap,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                textCapitalization: TextCapitalization.sentences,
                spellCheckConfiguration: const SpellCheckConfiguration(),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  fontFamily: 'monospace',
                  color: context.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: context.l10n.bodyHint,
                  hintStyle: TextStyle(
                    color: context.colorScheme.onSurfaceVariant.withAlpha(150),
                    fontFamily: 'monospace',
                  ),
                  filled: true,
                  fillColor: context.colorScheme.surfaceContainer,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.colorScheme.outline.withAlpha(80),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: context.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.outline.withAlpha(60),
        ),
      ),
      child: Row(
        children: [
          Text(
            context.l10n.contentLabel,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(width: 12),
          // Scrolls instead of overflowing on narrow phones
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Undo / Redo buttons
                    ValueListenableBuilder<UndoHistoryValue>(
                      valueListenable: _undoController,
                      builder: (context, undoValue, _) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ToolbarButton(
                              icon: Icons.undo_rounded,
                              tooltip: context.l10n.undoTooltip,
                              onPressed:
                                  undoValue.canUndo ? _undoController.undo : null,
                            ),
                            const SizedBox(width: 6),
                            _ToolbarButton(
                              icon: Icons.redo_rounded,
                              tooltip: context.l10n.redoTooltip,
                              onPressed:
                                  undoValue.canRedo ? _undoController.redo : null,
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(width: 6),
                    // Keyboard dismiss button
                    _ToolbarButton(
                      icon: Icons.keyboard_hide_rounded,
                      tooltip: context.l10n.hideKeyboardTooltip,
                      onPressed: () => FocusScope.of(context).unfocus(),
                    ),
                    const SizedBox(width: 6),
                    // Add Image button
                    _ToolbarButton(
                      icon: Icons.image_rounded,
                      tooltip: context.l10n.addImageTooltip,
                      onPressed: _isPickingImage ? null : _handleAddImage,
                      isLoading: _isPickingImage,
                    ),
                    const SizedBox(width: 6),
                    // Add Video button (no video_compress on Linux)
                    if (!isLinux) ...[
                      _ToolbarButton(
                        icon: Icons.videocam_rounded,
                        tooltip: context.l10n.addVideoTooltip,
                        onPressed: _isPickingVideo ? null : _handleAddVideo,
                        isLoading: _isPickingVideo,
                      ),
                      const SizedBox(width: 6),
                    ],
                    // Add YouTube video button
                    _ToolbarButton(
                      icon: Icons.smart_display_rounded,
                      tooltip: context.l10n.addYouTubeTooltip,
                      onPressed: _handleAddYouTube,
                    ),
                    const SizedBox(width: 6),
                    // Markdown help button
                    _ToolbarButton(
                      icon: Icons.help_outline_rounded,
                      tooltip: context.l10n.markdownHelpTooltip,
                      onPressed: _showMarkdownHelp,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTab() {
    return Consumer(
      builder: (context, ref, _) {
        final editorState = ref.watch(editorControllerProvider);
        final hasContent = editorState.bodyContent.trim().isNotEmpty;

        if (!hasContent) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 64,
                  color: context.colorScheme.onSurfaceVariant.withAlpha(100),
                ),
                const SizedBox(height: 16),
                Text(
                  context.l10n.nothingToPreviewYet,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.switchToWriteTab,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title preview
              if (editorState.title.isNotEmpty) ...[
                Text(
                  editorState.title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: context.colorScheme.onSurface,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  // Existing posts show their real date; today is only
                  // for brand-new posts
                  editorState.originalPost != null
                      ? _formatPostDate(editorState.originalPost!.date)
                      : _formatDate(context, DateTime.now()),
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                Divider(
                  height: 32,
                  color: context.colorScheme.outline,
                ),
              ],

              // Markdown content with smart image resolver
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context.colorScheme.outline.withAlpha(80),
                  ),
                ),
                child: MarkdownBody(
                  // Raw <video> and YouTube <iframe> blocks become placeholder
                  // "images" routed to _buildVideoPlaceholder via the builder
                  data: preprocessPreviewMarkdown(editorState.bodyContent),
                  selectable: true,
                  styleSheet: _buildMarkdownStyleSheet(),
                  sizedImageBuilder: (config) => _buildImage(config.uri, config.title, config.alt),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Smart image resolver - checks local cache first, falls back to GitHub.
  /// Video and YouTube placeholders injected by [preprocessPreviewMarkdown]
  /// render as a card instead (the preview never plays video).
  Widget _buildImage(Uri uri, String? title, String? alt) {
    final path = uri.toString();
    final filename = path.split('/').last;

    if (uri.scheme == videoPreviewScheme) {
      return _buildVideoPlaceholder(
        filename,
        isYouTube: alt == youTubePreviewAlt,
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final imageResolver = ref.read(imageResolverProvider.notifier);
        final imageManager = ref.read(imageManagerProvider.notifier);

        final (isLocal, resolvedPath) = imageResolver.resolveImagePath(path);

        // Watch upload state so overlays update as uploads progress
        final uploadStatus = ref.watch(imageManagerProvider)[filename];

        // Auth headers so private-repo images load from
        // raw.githubusercontent.com
        final authHeaders = ref.watch(imageAuthHeadersProvider);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isLocal
                    ? Image.file(
                        File(resolvedPath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImageError(alt ?? context.l10n.imageFallbackAlt),
                      )
                    : _buildNetworkImage(resolvedPath, alt, authHeaders),
              ),
              // Upload status overlay
              if (uploadStatus != null && uploadStatus.isUploading)
                Positioned.fill(child: _buildUploadingOverlay()),
              // Upload error overlay
              if (uploadStatus != null && uploadStatus.error != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildUploadErrorOverlay(filename, imageManager),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Rounded card standing in for a raw-HTML <video> embed: play badge,
  /// filename, and the same upload overlays as images. For a YouTube embed
  /// [filename] is the video id: it shows the thumbnail and opens on tap.
  Widget _buildVideoPlaceholder(String filename, {bool isYouTube = false}) {
    final label =
        filename.isEmpty ? context.l10n.videoFallbackLabel : filename;

    return Consumer(
      builder: (context, ref, _) {
        final imageManager = ref.read(imageManagerProvider.notifier);

        // Watch upload state so overlays update as uploads progress
        final uploadStatus = ref.watch(imageManagerProvider)[filename];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colorScheme.outline.withAlpha(100),
                  ),
                  image: isYouTube
                      ? DecorationImage(
                          image: NetworkImage(
                            'https://i.ytimg.com/vi/$filename/hqdefault.jpg',
                          ),
                          fit: BoxFit.cover,
                          // Offline: the bare card still reads as a video
                          onError: (_, __) {},
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.colorScheme.outline.withAlpha(120),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_arrow_rounded,
                        size: 32,
                        color: context.colorScheme.primary,
                      ),
                    ),
                    if (!isYouTube) ...[
                      const SizedBox(height: 12),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isYouTube)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => _launchExternal(
                      'https://www.youtube.com/watch?v=$filename',
                    ),
                  ),
                ),
              if (uploadStatus != null && uploadStatus.isUploading)
                Positioned.fill(child: _buildUploadingOverlay()),
              if (uploadStatus != null && uploadStatus.error != null)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildUploadErrorOverlay(filename, imageManager),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Dimmed 'Uploading...' overlay shared by image and video previews
  Widget _buildUploadingOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.uploadingEllipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom 'Upload failed / Retry' bar shared by image and video previews
  Widget _buildUploadErrorOverlay(String filename, ImageManager imageManager) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.error,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.uploadFailed,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
          // Real button (48dp tap target + TalkBack label), not a bare
          // GestureDetector on text
          TextButton(
            onPressed: () => imageManager.retryUpload(filename),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 32),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            child: Semantics(
              label: context.l10n.retryUploadOf(filename),
              child: Text(
                context.l10n.commonRetry,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Network image for the preview. GitHub raw URLs get the auth headers
  /// (private repos); other hosts must never receive the token.
  Widget _buildNetworkImage(
    String url,
    String? alt,
    AsyncValue<Map<String, String>?> authHeaders,
  ) {
    final isGitHubRaw = url.startsWith('https://raw.githubusercontent.com/');

    // Don't fire an unauthenticated request that would 404 on a private
    // repo - wait for the headers to resolve first
    if (isGitHubRaw && authHeaders.isLoading) {
      return _buildImageLoading();
    }

    return Image.network(
      url,
      headers: isGitHubRaw ? authHeaders.valueOrNull : null,
      fit: BoxFit.cover,
      width: double.infinity,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildImageLoading();
      },
      errorBuilder: (context, error, stackTrace) =>
          _buildImageError(alt ?? context.l10n.imageFallbackAlt),
    );
  }

  Widget _buildImageLoading() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: context.colorScheme.outline.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: CircularProgressIndicator(
          color: context.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildImageError(String alt) {
    return Container(
      height: 150,
      decoration: BoxDecoration(
        color: context.colorScheme.outline.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.error.withAlpha(50),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.broken_image_rounded,
              color: context.colorScheme.onSurfaceVariant,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              alt,
              style: TextStyle(
                color: context.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  MarkdownStyleSheet _buildMarkdownStyleSheet() {
    return MarkdownStyleSheet(
      p: TextStyle(
        fontSize: 15,
        height: 1.7,
        color: context.colorScheme.onSurface,
      ),
      h1: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: context.colorScheme.onSurface,
        height: 1.4,
      ),
      h2: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: context.colorScheme.onSurface,
        height: 1.4,
      ),
      h3: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: context.colorScheme.onSurface,
        height: 1.4,
      ),
      h4: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: context.colorScheme.onSurface,
        height: 1.4,
      ),
      h5: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: context.colorScheme.onSurface,
        height: 1.4,
      ),
      h6: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: context.colorScheme.onSurfaceVariant,
        height: 1.4,
      ),
      em: TextStyle(
        fontStyle: FontStyle.italic,
        color: context.colorScheme.onSurface,
      ),
      strong: TextStyle(
        fontWeight: FontWeight.w700,
        color: context.colorScheme.onSurface,
      ),
      blockquote: TextStyle(
        fontSize: 15,
        fontStyle: FontStyle.italic,
        color: context.colorScheme.onSurfaceVariant,
        height: 1.6,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: context.colorScheme.primary.withAlpha(150),
            width: 4,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 16),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        color: context.colorScheme.primary,
        backgroundColor: context.colorScheme.outline.withAlpha(100),
      ),
      codeblockDecoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colorScheme.outline.withAlpha(100),
        ),
      ),
      codeblockPadding: const EdgeInsets.all(16),
      listBullet: TextStyle(
        color: context.colorScheme.primary,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.colorScheme.outline.withAlpha(150),
            width: 1,
          ),
        ),
      ),
      a: TextStyle(
        color: context.colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    );
  }

  void _showPostSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const _PostSettingsSheet(),
    );
  }

  void _showMarkdownHelp() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.markdownQuickReference,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildMarkdownHelpRow('# Heading 1', context.l10n.mdLargeHeading),
            _buildMarkdownHelpRow('## Heading 2', context.l10n.mdMediumHeading),
            _buildMarkdownHelpRow('**bold**', context.l10n.mdBoldText),
            _buildMarkdownHelpRow('*italic*', context.l10n.mdItalicText),
            _buildMarkdownHelpRow('[link](url)', context.l10n.mdHyperlink),
            _buildMarkdownHelpRow('![alt](url)', context.l10n.mdImage),
            _buildMarkdownHelpRow('- item', context.l10n.mdBulletList),
            _buildMarkdownHelpRow('1. item', context.l10n.mdNumberedList),
            _buildMarkdownHelpRow('> quote', context.l10n.mdBlockQuote),
            _buildMarkdownHelpRow('`code`', context.l10n.mdInlineCode),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMarkdownHelpRow(String syntax, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 120,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.colorScheme.surface,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              syntax,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: context.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Format a post's date string (YYYY-MM-DD, possibly with a time suffix)
  String _formatPostDate(String date) {
    DateTime? parsed = DateTime.tryParse(date);
    parsed ??= date.length >= 10 ? DateTime.tryParse(date.substring(0, 10)) : null;
    return parsed != null ? _formatDate(context, parsed) : date;
  }

  String _formatDate(BuildContext context, DateTime date) {
    return DateFormat.yMMMMd(context.l10n.localeName).format(date);
  }
}

/// Post settings bottom sheet: publication date/time, layout, categories,
/// tags, and a read-only preview of custom front matter fields. All state
/// lives in [EditorController]; this sheet only renders and mutates it.
class _PostSettingsSheet extends ConsumerStatefulWidget {
  const _PostSettingsSheet();

  @override
  ConsumerState<_PostSettingsSheet> createState() => _PostSettingsSheetState();
}

class _PostSettingsSheetState extends ConsumerState<_PostSettingsSheet> {
  late final TextEditingController _layoutController;

  @override
  void initState() {
    super.initState();
    _layoutController = TextEditingController(
      text: ref.read(editorControllerProvider).layout,
    );
  }

  @override
  void dispose() {
    _layoutController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final state = ref.read(editorControllerProvider);
    final initial =
        state.publishDate ?? state.originalDate ?? DateTime.now();

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    ref.read(editorControllerProvider.notifier).updatePublishDate(
          DateTime(date.year, date.month, date.day, time.hour, time.minute),
        );
  }

  String _formatDateTime(DateTime dt) {
    final locale = context.l10n.localeName;
    final date = DateFormat.yMMMd(locale).format(dt);
    final time = DateFormat.Hm(locale).format(dt);
    return '$date · $time';
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorControllerProvider);
    final controller = ref.read(editorControllerProvider.notifier);
    final effectiveDate = editorState.publishDate ??
        editorState.originalDate ??
        DateTime.now();

    return Padding(
      // Keep the sheet above the keyboard while typing chips/layout
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tune_rounded,
                  color: context.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.postSettingsLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Publication date + time
            Text(
              context.l10n.publicationDateLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Material(
              color: context.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: context.colorScheme.outline.withAlpha(80),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_rounded,
                        size: 18,
                        color: context.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatDateTime(effectiveDate),
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: context.colorScheme.onSurfaceVariant.withAlpha(150),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (editorState.publishDate == null) ...[
              const SizedBox(height: 6),
              Text(
                editorState.originalDate != null
                    ? context.l10n.currentPostDateHint
                    : context.l10n.dateSetAutomaticallyHint,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorScheme.onSurfaceVariant.withAlpha(150),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Layout
            Text(
              context.l10n.layoutLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _layoutController,
              onChanged: controller.updateLayout,
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                color: context.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: context.l10n.layoutEmptyHint,
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: context.colorScheme.onSurfaceVariant.withAlpha(150),
                ),
                filled: true,
                fillColor: context.colorScheme.surfaceContainer,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.colorScheme.outline.withAlpha(80),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: context.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Categories
            _ChipEditor(
              label: context.l10n.categoriesLabel,
              hint: context.l10n.addCategoryHint,
              values: editorState.categories,
              onChanged: controller.updateCategories,
            ),
            const SizedBox(height: 20),

            // Tags
            _ChipEditor(
              label: context.l10n.tagsLabel,
              hint: context.l10n.addTagHint,
              values: editorState.tags,
              onChanged: controller.updateTags,
            ),

            // Custom (passthrough) fields - read-only preview
            if (editorState.passthrough.isNotEmpty) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    context.l10n.customFieldsLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.colorScheme.outline.withAlpha(80),
                  ),
                ),
                child: Text(
                  editorState.passthrough.values.join('\n'),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.customFieldsPreservedNote,
                style: TextStyle(
                  fontSize: 12,
                  color: context.colorScheme.onSurfaceVariant.withAlpha(150),
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Chip input for categories/tags: shows current values as removable
/// chips plus a text field that adds a chip on submit
class _ChipEditor extends StatefulWidget {
  final String label;
  final String hint;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  const _ChipEditor({
    required this.label,
    required this.hint,
    required this.values,
    required this.onChanged,
  });

  @override
  State<_ChipEditor> createState() => _ChipEditorState();
}

class _ChipEditorState extends State<_ChipEditor> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _add(String raw) {
    final value = raw.trim();
    _controller.clear();
    if (value.isEmpty) return;
    if (widget.values.contains(value)) return;
    widget.onChanged([...widget.values, value]);
    // Keep the keyboard up for entering several values in a row
    _focusNode.requestFocus();
  }

  void _remove(String value) {
    widget.onChanged(
      widget.values.where((v) => v != value).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        if (widget.values.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in widget.values)
                Chip(
                  label: Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                  backgroundColor: context.colorScheme.outline,
                  side: BorderSide.none,
                  deleteIcon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  onDeleted: () => _remove(value),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onSubmitted: _add,
          textInputAction: TextInputAction.done,
          style: TextStyle(
            fontSize: 14,
            color: context.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: context.colorScheme.onSurfaceVariant.withAlpha(150),
            ),
            filled: true,
            fillColor: context.colorScheme.surfaceContainer,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.colorScheme.outline.withAlpha(80),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: context.colorScheme.primary,
                width: 2,
              ),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                Icons.add_rounded,
                size: 20,
                color: context.colorScheme.primary,
              ),
              onPressed: () => _add(_controller.text),
            ),
          ),
        ),
      ],
    );
  }
}

/// Outcome of the pre-publish media gate dialogs (cancel = null)
enum _MediaGateChoice { wait, retry, publishAnyway }

/// Outcome of the publish-conflict dialog (cancel = null)
enum _ConflictChoice { overwrite, keepBoth }

/// Outcome of the offline-publish dialog (dismissed = keep editing)
enum _OfflineChoice { queue, discard, keepEditing }

/// Toolbar button widget
class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _ToolbarButton({
    required this.icon,
    this.tooltip,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null && !isLoading;

    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.colorScheme.outline.withAlpha(60),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colorScheme.primary,
                  ),
                )
              : Icon(
                  icon,
                  size: 16,
                  color: isDisabled
                      ? context.colorScheme.onSurfaceVariant.withAlpha(90)
                      : context.colorScheme.primary,
                ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}
