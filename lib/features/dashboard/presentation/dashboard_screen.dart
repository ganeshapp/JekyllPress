import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/models/app_config.dart';
import '../../../core/models/blog_post.dart';
import '../../../core/models/local_draft.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/drafts_provider.dart';
import '../../../core/providers/image_provider.dart';
import '../../../core/providers/posts_provider.dart';
import '../../../core/providers/publish_provider.dart';
import '../../../core/providers/queue_provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/publish_queue_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/desktop_content_width.dart';
import '../../../core/utils/frontmatter_parser.dart';
import '../../../core/utils/permalink.dart';
import '../../../l10n/l10n.dart';
import '../../about/presentation/about_screen.dart';
import '../../config/presentation/config_screen.dart';
import '../../editor/presentation/editor_screen.dart';
import '../widgets/post_card.dart';
import '../widgets/empty_posts_view.dart';
import '../../../core/utils/external_url.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late TabController _tabController;

  // Client-side search over the cached posts (both tabs)
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
    
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _animController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await ref.read(postsNotifierProvider.notifier).refresh();
  }

  Future<void> _navigateToEditor([BlogPost? post]) async {
    LocalDraft? resumeDraft;

    // Before opening a published post, check for unpublished edits so a
    // newer edit-draft is never silently overwritten
    if (post != null) {
      final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
      final existingDraft = draftsNotifier.getDraftForPost(post);
      final hasDivergingEdits = existingDraft != null &&
          (existingDraft.title != post.title ||
              existingDraft.bodyContent != post.bodyContent);

      if (hasDivergingEdits) {
        final resume = await _confirmResumeDraft(existingDraft);
        if (resume == null) return; // Dialog dismissed - don't open
        if (resume) {
          resumeDraft = existingDraft;
        } else {
          await draftsNotifier.deleteDraft(existingDraft.id);
        }
      }
    }

    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => EditorScreen(
          post: post,
          resumeDraft: resumeDraft,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.05);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var fadeTween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
          
          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      // Refresh drafts when returning from editor
      ref.read(draftsNotifierProvider.notifier).refresh();
    });
  }

  void _navigateToEditorWithDraft(LocalDraft draft) {
    // Convert draft to BlogPost for the editor
    BlogPost? post;
    if (draft.isEditingExisting) {
      post = BlogPost(
        sha: draft.originalSha,
        fileName: draft.originalFileName,
        filePath: draft.originalFilePath,
        title: draft.title,
        date: draft.originalDate ?? '',
        rawFrontmatter: draft.originalFrontmatter,
        bodyContent: draft.bodyContent,
      );
    }
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => EditorScreen(
          post: post,
          resumeDraft: draft,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.05);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var fadeTween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
          
          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(
              opacity: animation.drive(fadeTween),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) {
      // Refresh drafts when returning from editor
      ref.read(draftsNotifierProvider.notifier).refresh();
    });
  }

  /// Ask whether to resume or discard unpublished edits for a post.
  /// Returns true = resume, false = discard, null = dismissed.
  Future<bool?> _confirmResumeDraft(LocalDraft draft) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.unpublishedEditsTitle),
        content: Text(
          context.l10n
              .unpublishedEditsBody(_formatTimeAgo(draft.lastModified)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.error,
            ),
            child: Text(context.l10n.discardEdits),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.resumeMyEdits),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final configState = ref.watch(configNotifierProvider);
    final postsState = ref.watch(postsNotifierProvider);
    final draftsState = ref.watch(draftsNotifierProvider);
    final publishQueue = ref.watch(publishQueueNotifierProvider);

    final user = authState is AuthAuthenticated ? authState.user : null;
    final config = configState is ConfigLoaded ? configState.config : null;
    final draftsCount = draftsState.drafts.length +
        _remoteDrafts(postsState, config).length;

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient(context),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: DesktopContentWidth(
              child: Column(
                children: [
                  _buildHeader(context, ref, user, config),
                  if (_isSearching) _buildSearchBar(),
                  if (publishQueue.isNotEmpty) _buildQueueBanner(publishQueue),
                  if (config != null && config.contentDirs.length > 1)
                    _buildContentDirSwitcher(config),
                  _buildTabBar(draftsCount),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildContent(postsState, config),
                        _buildDraftsContent(draftsState, postsState, config),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  /// All cached posts regardless of load/error state
  List<BlogPost> _allPosts(PostsState postsState) {
    return switch (postsState) {
      PostsLoaded(posts: final p) => p,
      PostsLoading(cachedPosts: final p) => p,
      PostsError(cachedPosts: final p) => p,
      _ => const <BlogPost>[],
    };
  }

  /// Jekyll drafts synced from the configured drafts dir on GitHub
  List<BlogPost> _remoteDrafts(PostsState postsState, AppConfig? config) {
    if (config == null) return const [];
    return _allPosts(postsState)
        .where((p) => isRemoteDraft(p, config))
        .toList();
  }

  /// Synced posts that are NOT remote drafts (the Published tab's list)
  List<BlogPost> _publishedPosts(List<BlogPost> posts, AppConfig? config) {
    if (config == null) return posts;
    return posts.where((p) => !isRemoteDraft(p, config)).toList();
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(
          fontSize: 14,
          color: context.colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          hintText: context.l10n.searchPostsHint,
          hintStyle: TextStyle(
            fontSize: 14,
            color: context.colorScheme.onSurfaceVariant.withAlpha(150),
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: context.colorScheme.onSurfaceVariant,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: context.colorScheme.surfaceContainer,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
    );
  }

  Widget _buildTabBar(int draftsCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
                const Icon(Icons.cloud_done_rounded, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.tabPublished),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_note_rounded, size: 18),
                const SizedBox(width: 8),
                Text(context.l10n.tabDrafts),
                if (draftsCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.colorScheme.primary.withAlpha(40),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$draftsCount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    dynamic user,
    AppConfig? config,
  ) {
    final postsState = ref.watch(postsNotifierProvider);
    final isRefreshing = postsState is PostsLoaded && postsState.isRefreshing;
    final syncLabel = _syncProgressLabel(postsState);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          if (user != null)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.colorScheme.primary.withAlpha(50),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(user.avatarUrl),
                backgroundColor: context.colorScheme.outline,
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        config?.repoName ?? context.l10n.blogFallbackTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRefreshing) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (syncLabel != null)
                  Text(
                    syncLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          color: context.colorScheme.primary,
                        ),
                  )
                else if (config != null)
                  Text(
                    '${config.repoOwner} · ${config.branch}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                        ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              _isSearching ? Icons.search_off_rounded : Icons.search_rounded,
            ),
            color:
                _isSearching ? context.colorScheme.primary : context.colorScheme.onSurfaceVariant,
            tooltip: context.l10n.searchPostsTooltip,
            onPressed: _toggleSearch,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: context.colorScheme.onSurfaceVariant,
            tooltip: context.l10n.refreshPostsTooltip,
            onPressed: _onRefresh,
          ),
          PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert_rounded,
              color: context.colorScheme.onSurfaceVariant,
            ),
            tooltip: context.l10n.moreOptionsTooltip,
            itemBuilder: (context) => [
              if (config != null && config.siteUrl.isNotEmpty)
                PopupMenuItem(
                  value: 'open_site',
                  child: Row(
                    children: [
                      const Icon(Icons.open_in_new_rounded, size: 20),
                      const SizedBox(width: 12),
                      Text(context.l10n.menuOpenSite),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'change_repo',
                child: Row(
                  children: [
                    const Icon(Icons.swap_horiz_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text(context.l10n.menuChangeRepository),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    const Icon(Icons.brightness_6_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text(context.l10n.themeLabel),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text(context.l10n.aboutLabel),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text(context.l10n.logoutLabel),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                await _confirmLogout();
              } else if (value == 'change_repo') {
                if (config != null) await _openRepositorySettings(config);
              } else if (value == 'open_site') {
                if (config != null) _launchExternal(config.siteUrl);
              } else if (value == 'theme') {
                await _showThemePicker();
              } else if (value == 'about') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AboutScreen(),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  /// Manual theme override: system (follow Android), light, or dark.
  /// Persisted via [ThemeModeNotifier] so it survives restarts.
  Future<void> _showThemePicker() async {
    final current = ref.read(themeModeNotifierProvider);
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(context.l10n.themeLabel),
        children: [
          for (final (mode, label, icon) in [
            (
              ThemeMode.system,
              context.l10n.themeSystemDefault,
              Icons.brightness_auto_rounded
            ),
            (ThemeMode.light, context.l10n.themeLight, Icons.light_mode_rounded),
            (ThemeMode.dark, context.l10n.themeDark, Icons.dark_mode_rounded),
          ])
            ListTile(
              leading: Icon(icon),
              title: Text(label),
              trailing: mode == current
                  ? Icon(
                      Icons.check_rounded,
                      color: context.colorScheme.primary,
                    )
                  : null,
              selected: mode == current,
              onTap: () => Navigator.pop(context, mode),
            ),
        ],
      ),
    );
    if (selected == null || selected == current) return;
    await ref.read(themeModeNotifierProvider.notifier).setMode(selected);
  }

  /// Confirm and perform logout: clears the token and ALL local data
  /// (posts cache, drafts, image map, local images) so nothing leaks to
  /// the next account on this device
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.logoutDialogTitle),
        content: Text(context.l10n.logoutDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.error,
            ),
            child: Text(context.l10n.logoutLabel),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _clearLocalData();
    await ref.read(configNotifierProvider.notifier).clearConfig();
    await ref.read(authNotifierProvider.notifier).logout();
  }

  /// Open the config screen PRE-FILLED with the current settings. When
  /// it pops after a save: a repo/branch change removes the repo-scoped
  /// local data (the config screen confirms this first), any save
  /// triggers a resync.
  Future<void> _openRepositorySettings(AppConfig config) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ConfigScreen(initialConfig: config),
      ),
    );
    if (saved != true || !mounted) return;

    final newConfig =
        ref.read(configNotifierProvider.notifier).currentConfig;
    if (newConfig == null) return;

    final repoChanged = newConfig.repoOwner != config.repoOwner ||
        newConfig.repoName != config.repoName ||
        newConfig.branch != config.branch;
    if (repoChanged) {
      // Drafts and cached posts belong to the previous repository
      await _clearLocalData();
    }
    await ref.read(postsNotifierProvider.notifier).refresh();
  }

  /// 'Syncing x of y...' while changed post bodies are being fetched
  String? _syncProgressLabel(PostsState postsState) {
    if (postsState is PostsLoaded &&
        postsState.isRefreshing &&
        postsState.syncTotal != null) {
      return context.l10n
          .syncingProgress(postsState.syncDone ?? 0, postsState.syncTotal!);
    }
    return null;
  }

  /// Choice chips to switch the content dir being synced/published
  /// (only shown when collections beyond the posts folder are configured)
  Widget _buildContentDirSwitcher(AppConfig config) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final dir in config.contentDirs)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(dir),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: dir == config.activeContentDir
                      ? context.colorScheme.onPrimary
                      : context.colorScheme.onSurfaceVariant,
                ),
                selected: dir == config.activeContentDir,
                selectedColor: context.colorScheme.primary,
                backgroundColor: context.colorScheme.surfaceContainer,
                showCheckmark: false,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: context.colorScheme.outline.withAlpha(80),
                  ),
                ),
                onSelected: (_) => _switchContentDir(config, dir),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _switchContentDir(AppConfig config, String dir) async {
    if (dir == config.activeContentDir) return;
    HapticFeedback.selectionClick();
    await ref.read(configNotifierProvider.notifier).setActiveContentDir(dir);
    await ref.read(postsNotifierProvider.notifier).refresh();
  }

  /// Wipe all repo/account-scoped local data: the offline publish queue,
  /// posts cache, drafts, the local image map, and the local images
  /// directory
  Future<void> _clearLocalData() async {
    // Queue first: a queued item carries its own body and publishes
    // against whatever config is active when it flushes, so leaving it
    // behind would push the previous repo's post into the next one
    await ref.read(publishQueueNotifierProvider.notifier).clearAll();
    await ref.read(postsNotifierProvider.notifier).clearAll();
    await ref.read(draftsNotifierProvider.notifier).clearAll();
    await ref.read(localImageMapBoxProvider).clear();
    await ref.read(imageServiceProvider).clearAllLocalImages();
  }

  Widget _buildContent(PostsState postsState, AppConfig? config) {
    return switch (postsState) {
      PostsInitial() => _buildLoadingView(),
      PostsLoading(cachedPosts: final cached) => cached.isEmpty
          ? _buildLoadingView()
          : _buildFilteredPostsList(cached, config),
      PostsLoaded(
        posts: final posts,
        isRefreshing: final isRefreshing,
        syncError: final syncError,
        lastSynced: final lastSynced,
      ) =>
        _publishedPosts(posts, config).isEmpty
            // The very first sync starts from an empty cache - show the
            // loading view (with progress) rather than 'No Posts Yet'
            ? (isRefreshing
                ? _buildLoadingView(_syncProgressLabel(postsState))
                : EmptyPostsView(
                    postsFolder: config?.activeContentDir ?? '_posts',
                  ))
            : _buildFilteredPostsList(
                posts,
                config,
                errorMessage: syncError,
                lastSynced: lastSynced,
              ),
      PostsError(message: final msg, cachedPosts: final cached) => cached.isEmpty
          ? _buildErrorView(msg)
          : _buildFilteredPostsList(cached, config, errorMessage: msg),
    };
  }

  /// Published-tab list: remote drafts filtered out, search applied
  Widget _buildFilteredPostsList(
    List<BlogPost> allPosts,
    AppConfig? config, {
    String? errorMessage,
    DateTime? lastSynced,
  }) {
    final published = _publishedPosts(allPosts, config);
    final visible = filterPostsByQuery(published, _searchQuery);
    if (published.isNotEmpty && visible.isEmpty) {
      return _buildNoMatchesView();
    }
    return _buildPostsList(
      visible,
      config,
      errorMessage: errorMessage,
      lastSynced: lastSynced,
    );
  }

  Widget _buildLoadingView([String? label]) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: context.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            label ?? context.l10n.loadingPosts,
            style: context.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colorScheme.error.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: context.colorScheme.error,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.l10n.failedToLoadPosts,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList(
    List<BlogPost> posts,
    AppConfig? config, {
    String? errorMessage,
    DateTime? lastSynced,
  }) {
    // Header row: sync-failure banner takes priority, otherwise a subtle
    // "last synced" caption when we know the sync time
    final hasHeader = errorMessage != null || lastSynced != null;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: context.colorScheme.primary,
      backgroundColor: context.colorScheme.surfaceContainerHigh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: posts.length + (hasHeader ? 1 : 0),
        itemBuilder: (context, index) {
          if (hasHeader && index == 0) {
            return errorMessage != null
                ? _buildSyncErrorBanner(errorMessage)
                : _buildLastSyncedCaption(lastSynced!);
          }

          final postIndex = hasHeader ? index - 1 : index;
          final post = posts[postIndex];

          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 300 + (postIndex * 50)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: Opacity(opacity: value, child: child),
              );
            },
            child: _buildPublishedPostCard(post, config),
          );
        },
      ),
    );
  }

  Widget _buildPublishedPostCard(BlogPost post, AppConfig? config) {
    final canAct = post.sha != null;
    return PostCard(
      post: post,
      onTap: () => _navigateToEditor(post),
      onViewPost: canAct &&
              post.fileName != null &&
              (config?.siteUrl.isNotEmpty ?? false)
          ? () => _openPostUrl(post, config!)
          : null,
      onDelete: canAct ? () => _confirmDeleteFromGitHub(post) : null,
    );
  }

  /// Card for a Jekyll draft that lives on GitHub (Drafts tab section)
  Widget _buildRemoteDraftCard(BlogPost draft) {
    final canAct = draft.sha != null;
    return PostCard(
      post: draft,
      isRemoteDraft: true,
      onTap: () => _navigateToEditor(draft),
      onPromote: canAct ? () => _confirmPromoteDraft(draft) : null,
      onDelete: canAct ? () => _confirmDeleteFromGitHub(draft) : null,
    );
  }

  Widget _buildNoMatchesView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: context.colorScheme.onSurfaceVariant.withAlpha(120),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noPostsMatch,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.tryDifferentSearch,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  /// Open a URL in the browser (best-effort).
  ///
  /// [openExternalUrl] handles its own fallbacks and tells the user if it had
  /// to copy the link instead, so there is nothing to report here.
  Future<void> _launchExternal(String url) => openExternalUrl(context, url);

  /// Open the post's public URL built from the site config and the
  /// site's permalink pattern
  void _openPostUrl(BlogPost post, AppConfig config) {
    final categories = post.rawFrontmatter == null
        ? const <String>[]
        : FrontmatterParser.parseFields(post.rawFrontmatter!).categories;
    final url = buildPostUrl(
      siteUrl: config.siteUrl,
      baseurl: config.baseurl,
      permalinkPattern: config.permalinkPattern,
      fileName: post.fileName!,
      date: post.dateTime,
      categories: categories,
    );
    if (url != null) _launchExternal(url);
  }

  /// Confirm, then delete the post's file from GitHub and drop it from
  /// the cache/state
  Future<void> _confirmDeleteFromGitHub(BlogPost post) async {
    final fileName =
        post.fileName ?? post.filePath ?? context.l10n.thisPostFallback;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteFromGitHubTitle),
        content: Text(context.l10n.deleteFromGitHubBody(fileName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.error,
            ),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await ref
        .read(publishNotifierProvider.notifier)
        .deleteRemotePost(post);
    if (!mounted) return;

    if (error == null) {
      await ref.read(postsNotifierProvider.notifier).removePost(post);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.deletedFile(fileName)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // Background is overridden, so the text colour must come from the
          // matching `on` role (the theme default is onSurface, which is
          // unreadable on `error` in light mode)
          content: Text(
            error,
            style: TextStyle(color: context.colorScheme.onError),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.colorScheme.error,
        ),
      );
    }
  }

  /// Confirm, then move a remote draft into the active content dir
  Future<void> _confirmPromoteDraft(BlogPost draft) async {
    final config = ref.read(configNotifierProvider.notifier).currentConfig;
    if (config == null) return;
    final fileName = draft.fileName ?? context.l10n.thisDraftFallback;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.promoteDialogTitle),
        content: Text(context.l10n.promoteDialogBody(
          fileName,
          config.draftsPath,
          config.activeContentDir,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.promoteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await ref
        .read(publishNotifierProvider.notifier)
        .promoteRemoteDraft(draft);
    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.draftPromotedToPost),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          // Background is overridden, so the text colour must come from the
          // matching `on` role (the theme default is onSurface, which is
          // unreadable on `error` in light mode)
          content: Text(
            error,
            style: TextStyle(color: context.colorScheme.onError),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: context.colorScheme.error,
        ),
      );
    }
    await ref.read(postsNotifierProvider.notifier).refresh();
  }

  Widget _buildSyncErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colorScheme.error.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.error.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.sync_problem_rounded,
            color: context.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.syncFailedShowingCached,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colorScheme.error,
                    fontSize: 13,
                  ),
            ),
          ),
          TextButton(
            onPressed: _onRefresh,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildLastSyncedCaption(DateTime lastSynced) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        context.l10n.lastSyncedCaption(_formatTimeAgo(lastSynced)),
        style: TextStyle(
          fontSize: 11,
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Banner shown while offline-queued posts wait to publish. Items whose
  /// automatic retries ran out get a tappable failure note that reopens
  /// them in the editor (and removes them from the queue).
  Widget _buildQueueBanner(List<QueuedPublish> queue) {
    final failed = queue.where((item) => item.isFailed).toList();
    final waitingCount = queue.length - failed.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.primary.withAlpha(50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_send_rounded,
                color: context.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  waitingCount > 0
                      ? context.l10n.queueWaitingCount(waitingCount)
                      : context.l10n.queueFailedCount(failed.length),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colorScheme.primary,
                        fontSize: 13,
                      ),
                ),
              ),
              TextButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  ref
                      .read(publishQueueNotifierProvider.notifier)
                      .processQueue(manual: true);
                },
                child: Text(context.l10n.publishNow),
              ),
            ],
          ),
          for (final item in failed)
            InkWell(
              onTap: () => _reopenQueuedItem(item),
              borderRadius: BorderRadius.circular(8),
              child: Semantics(
                button: true,
                label: context.l10n.failedQueueItemSemantics(
                  item.title.isEmpty ? context.l10n.commonUntitled : item.title,
                ),
                child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: context.colorScheme.error,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.couldNotPublishTapToEdit(
                          item.title.isEmpty
                              ? context.l10n.commonUntitled
                              : item.title,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colorScheme.error,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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

  /// Reopen a queued (failed) publish in the editor with its content
  /// restored, removing it from the queue. The safety-net draft is the
  /// content source; when it is gone, one is rebuilt from the queue item.
  Future<void> _reopenQueuedItem(QueuedPublish item) async {
    final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
    var draft = item.safetyDraftId == null
        ? null
        : draftsNotifier.getDraft(item.safetyDraftId!);
    if (draft == null) {
      draft = item.isUpdate
          ? LocalDraft.fromExistingPost(
              id: 'draft_edit_${item.originalFileName ?? item.id}',
              title: item.title,
              bodyContent: item.bodyContent,
              sha: item.originalSha ?? '',
              fileName: item.originalFileName ?? '',
              date: item.originalDate ?? '',
              rawFrontmatter: item.originalFrontmatter,
              filePath: item.originalPath,
            )
          : LocalDraft.newDraft(
              id: 'draft_${DateTime.now().millisecondsSinceEpoch}',
              title: item.title,
              bodyContent: item.bodyContent,
            );
      await draftsNotifier.saveDraft(draft);
    }
    await ref
        .read(publishQueueNotifierProvider.notifier)
        .removeItem(item.id);
    if (!mounted) return;
    _navigateToEditorWithDraft(draft);
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _navigateToEditor(),
      backgroundColor: context.colorScheme.primary,
      foregroundColor: context.colorScheme.onPrimary,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        context.l10n.newPostAction,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  /// Drafts tab: Jekyll drafts on GitHub (under the drafts dir) plus the
  /// device-local edit drafts, in two labeled sections
  Widget _buildDraftsContent(
    DraftsState draftsState,
    PostsState postsState,
    AppConfig? config,
  ) {
    if (draftsState.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: context.colorScheme.primary,
        ),
      );
    }

    final remoteDrafts = _remoteDrafts(postsState, config);
    final localDrafts = draftsState.drafts;
    final visibleRemote = filterPostsByQuery(remoteDrafts, _searchQuery);
    final visibleLocal = _filterLocalDrafts(localDrafts);

    if (visibleRemote.isEmpty && visibleLocal.isEmpty) {
      // Distinguish "no drafts at all" from "search matched nothing"
      return remoteDrafts.isEmpty && localDrafts.isEmpty
          ? _buildEmptyDraftsView()
          : _buildNoMatchesView();
    }

    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        ref.read(draftsNotifierProvider.notifier).refresh();
        await ref.read(postsNotifierProvider.notifier).refresh();
      },
      color: context.colorScheme.primary,
      backgroundColor: context.colorScheme.surfaceContainerHigh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        children: [
          if (visibleRemote.isNotEmpty) ...[
            _buildDraftsSectionHeader(
              Icons.cloud_queue_rounded,
              context.l10n
                  .draftsOnGitHubSection(config?.draftsPath ?? '_drafts'),
            ),
            for (final draft in visibleRemote) _buildRemoteDraftCard(draft),
          ],
          if (visibleLocal.isNotEmpty) ...[
            _buildDraftsSectionHeader(
              Icons.smartphone_rounded,
              context.l10n.draftsOnDeviceSection,
            ),
            for (final draft in visibleLocal) _buildDraftCard(draft),
          ],
        ],
      ),
    );
  }

  List<LocalDraft> _filterLocalDrafts(List<LocalDraft> drafts) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return drafts;
    return drafts
        .where((d) =>
            d.title.toLowerCase().contains(q) ||
            d.bodyContent.toLowerCase().contains(q))
        .toList();
  }

  Widget _buildDraftsSectionHeader(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: context.colorScheme.onSurfaceVariant.withAlpha(180),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDraftsView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.colorScheme.outline.withAlpha(30),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.drafts_rounded,
              size: 56,
              color: context.colorScheme.onSurfaceVariant.withAlpha(120),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.noDraftsYet,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.colorScheme.onSurface,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.draftsEmptyBody,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(LocalDraft draft) {
    final timeAgo = _formatTimeAgo(draft.lastModified);
    final isEditingExisting = draft.isEditingExisting;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToEditorWithDraft(draft),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.colorScheme.outline.withAlpha(80),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Semantics(
                      label: isEditingExisting
                          ? context.l10n.draftStatusEditingSemantics
                          : context.l10n.draftStatusNewSemantics,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEditingExisting
                              ? context.appColors.info.withAlpha(30)
                              : context.colorScheme.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isEditingExisting ? Icons.edit_rounded : Icons.fiber_new_rounded,
                              size: 12,
                              color: isEditingExisting
                                  ? context.appColors.info
                                  : context.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isEditingExisting
                                  ? context.l10n.editingStatus
                                  : context.l10n.newStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isEditingExisting
                                    ? context.appColors.info
                                    : context.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // Delete button (48dp tap target + label for TalkBack)
                    IconButton(
                      onPressed: () => _confirmDeleteDraft(draft),
                      tooltip: context.l10n.deleteDraftTooltip,
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  draft.title.isEmpty
                      ? context.l10n.commonUntitled
                      : draft.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: draft.title.isEmpty
                        ? context.colorScheme.onSurfaceVariant
                        : context.colorScheme.onSurface,
                    fontStyle: draft.title.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (draft.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    draft.excerpt,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteDraft(LocalDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.deleteDraftDialogTitle),
        content: Text(
          context.l10n.deleteDraftDialogBody(
            draft.title.isEmpty ? context.l10n.commonUntitled : draft.title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: context.colorScheme.error,
            ),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(draftsNotifierProvider.notifier).deleteDraft(draft.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.draftDeleted),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Localized relative time; falls back to a locale-aware short date
  /// past one week
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return context.l10n.timeAgoJustNow;
    } else if (difference.inMinutes < 60) {
      return context.l10n.timeAgoMinutes(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return context.l10n.timeAgoHours(difference.inHours);
    } else if (difference.inDays < 7) {
      return context.l10n.timeAgoDays(difference.inDays);
    } else {
      return DateFormat.yMd(context.l10n.localeName).format(dateTime);
    }
  }
}
