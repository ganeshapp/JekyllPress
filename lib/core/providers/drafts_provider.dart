import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/local_draft.dart';
import '../models/blog_post.dart';

part 'drafts_provider.g.dart';

/// Provider for accessing the drafts Hive box
@riverpod
Box<LocalDraft> draftsBox(DraftsBoxRef ref) {
  return Hive.box<LocalDraft>('drafts_box');
}

/// State for draft save operations
enum DraftSaveStatus {
  idle,
  saving,
  saved,
  error,
}

/// State class for the drafts notifier
class DraftsState {
  final List<LocalDraft> drafts;
  final bool isLoading;
  final String? error;

  const DraftsState({
    this.drafts = const [],
    this.isLoading = false,
    this.error,
  });

  DraftsState copyWith({
    List<LocalDraft>? drafts,
    bool? isLoading,
    String? error,
  }) {
    return DraftsState(
      drafts: drafts ?? this.drafts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// Manages local drafts - saving, loading, and deleting
@riverpod
class DraftsNotifier extends _$DraftsNotifier {
  @override
  DraftsState build() {
    _loadDrafts();
    return const DraftsState(isLoading: true);
  }

  void _loadDrafts() {
    try {
      final box = ref.read(draftsBoxProvider);
      final drafts = box.values.toList();
      // Sort by last modified (newest first)
      drafts.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      state = DraftsState(drafts: drafts);
    } catch (e) {
      state = DraftsState(error: 'Failed to load drafts: $e');
    }
  }

  /// Save or update a draft
  Future<void> saveDraft(LocalDraft draft) async {
    try {
      final box = ref.read(draftsBoxProvider);
      await box.put(draft.id, draft);
      _loadDrafts();
    } catch (e) {
      state = state.copyWith(error: 'Failed to save draft: $e');
    }
  }

  /// Delete a draft by ID
  Future<void> deleteDraft(String draftId) async {
    try {
      final box = ref.read(draftsBoxProvider);
      await box.delete(draftId);
      _loadDrafts();
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete draft: $e');
    }
  }

  /// Get a specific draft by ID
  LocalDraft? getDraft(String draftId) {
    final box = ref.read(draftsBoxProvider);
    return box.get(draftId);
  }

  /// Create a new draft for a new post
  LocalDraft createNewDraft() {
    final id = 'draft_${DateTime.now().millisecondsSinceEpoch}';
    return LocalDraft.newDraft(id: id);
  }

  /// Create a draft from an existing BlogPost (for editing)
  LocalDraft createDraftFromPost(BlogPost post) {
    final id = 'draft_edit_${post.fileName ?? DateTime.now().millisecondsSinceEpoch}';
    return LocalDraft.fromExistingPost(
      id: id,
      title: post.title,
      bodyContent: post.bodyContent,
      sha: post.sha ?? '',
      fileName: post.fileName ?? '',
      date: post.date,
      rawFrontmatter: post.rawFrontmatter,
    );
  }

  /// Check if there's an existing draft for a post
  LocalDraft? getDraftForPost(BlogPost post) {
    if (post.fileName == null) return null;
    final draftId = 'draft_edit_${post.fileName}';
    return getDraft(draftId);
  }

  /// Refresh drafts list
  void refresh() {
    _loadDrafts();
  }
}

/// Manages the current editing session's draft state
@riverpod
class CurrentDraftNotifier extends _$CurrentDraftNotifier {
  LocalDraft? _currentDraft;
  DateTime? _lastSavedAt;

  @override
  DraftSaveStatus build() {
    return DraftSaveStatus.idle;
  }

  /// Get current draft
  LocalDraft? get currentDraft => _currentDraft;
  
  /// Get last saved timestamp
  DateTime? get lastSavedAt => _lastSavedAt;

  /// Initialize with a new draft
  void initializeNewDraft() {
    final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
    _currentDraft = draftsNotifier.createNewDraft();
    _lastSavedAt = null;
    state = DraftSaveStatus.idle;
  }

  /// Initialize with an existing draft (resuming)
  void initializeWithDraft(LocalDraft draft) {
    _currentDraft = draft;
    _lastSavedAt = draft.lastModified;
    state = DraftSaveStatus.idle;
  }

  /// Initialize draft for editing an existing post
  void initializeForExistingPost(BlogPost post) {
    final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
    
    // Check if there's already a draft for this post
    final existingDraft = draftsNotifier.getDraftForPost(post);
    if (existingDraft != null) {
      _currentDraft = existingDraft;
      _lastSavedAt = existingDraft.lastModified;
    } else {
      _currentDraft = draftsNotifier.createDraftFromPost(post);
      _lastSavedAt = null;
    }
    state = DraftSaveStatus.idle;
  }

  /// Update draft content (called on text changes, debounced externally)
  Future<void> updateAndSave({
    String? title,
    String? bodyContent,
  }) async {
    if (_currentDraft == null) return;

    state = DraftSaveStatus.saving;

    try {
      _currentDraft = _currentDraft!.copyWith(
        title: title,
        bodyContent: bodyContent,
        lastModified: DateTime.now(),
      );

      // Only save if there's meaningful content
      if (_currentDraft!.hasContent) {
        final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
        await draftsNotifier.saveDraft(_currentDraft!);
        _lastSavedAt = _currentDraft!.lastModified;
      }

      state = DraftSaveStatus.saved;
      
      // Reset to idle after a short delay
      await Future.delayed(const Duration(seconds: 2));
      if (state == DraftSaveStatus.saved) {
        state = DraftSaveStatus.idle;
      }
    } catch (e) {
      state = DraftSaveStatus.error;
    }
  }

  /// Force save immediately (used on app background)
  Future<void> forceSave({
    required String title,
    required String bodyContent,
  }) async {
    if (_currentDraft == null) return;

    _currentDraft = _currentDraft!.copyWith(
      title: title,
      bodyContent: bodyContent,
      lastModified: DateTime.now(),
    );

    if (_currentDraft!.hasContent) {
      final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
      await draftsNotifier.saveDraft(_currentDraft!);
      _lastSavedAt = _currentDraft!.lastModified;
    }
  }

  /// Clear current draft after successful publish
  Future<void> clearAfterPublish() async {
    if (_currentDraft == null) return;

    final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
    await draftsNotifier.deleteDraft(_currentDraft!.id);
    _currentDraft = null;
    _lastSavedAt = null;
    state = DraftSaveStatus.idle;
  }

  /// Discard current draft without saving
  Future<void> discardDraft() async {
    if (_currentDraft == null) return;

    // Only delete from storage if it was previously saved
    if (_lastSavedAt != null) {
      final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
      await draftsNotifier.deleteDraft(_currentDraft!.id);
    }
    
    _currentDraft = null;
    _lastSavedAt = null;
    state = DraftSaveStatus.idle;
  }

  /// Clear state (on editor close)
  void clear() {
    _currentDraft = null;
    _lastSavedAt = null;
    state = DraftSaveStatus.idle;
  }
}
