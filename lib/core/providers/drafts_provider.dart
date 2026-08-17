import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/local_draft.dart';
import '../models/blog_post.dart';

part 'drafts_provider.g.dart';

/// Provider for accessing the drafts Hive box
@riverpod
Box<LocalDraft> draftsBox(Ref ref) {
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
    // Load drafts synchronously and return the result directly
    try {
      final box = ref.read(draftsBoxProvider);
      final drafts = box.values.toList();
      // Sort by last modified (newest first)
      drafts.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      return DraftsState(drafts: drafts);
    } catch (e) {
      return DraftsState(error: 'Failed to load drafts: $e');
    }
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

  /// Delete all drafts (used on logout / repository change)
  Future<void> clearAll() async {
    try {
      final box = ref.read(draftsBoxProvider);
      await box.clear();
      _loadDrafts();
    } catch (e) {
      state = state.copyWith(error: 'Failed to clear drafts: $e');
    }
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

  /// True while clearAfterPublish is deleting the draft. Blocks a debounced
  /// autosave from resurrecting the just-deleted draft.
  bool _isClearing = false;

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
  ///
  /// Returns true if the draft was persisted to storage. Empty content is
  /// treated as user intent to discard: any stored record is deleted and
  /// false is returned (also false when empty and nothing was stored).
  Future<bool> updateAndSave({
    String? title,
    String? bodyContent,
  }) async {
    if (_currentDraft == null || _isClearing) return false;

    try {
      final updatedDraft = _currentDraft!.copyWith(
        title: title,
        bodyContent: bodyContent,
        lastModified: DateTime.now(),
      );
      _currentDraft = updatedDraft;

      // Empty content: delete any stored record so old content doesn't
      // resurrect on next open
      if (!updatedDraft.hasContent) {
        await _deleteStoredDraftIfExists(updatedDraft.id);
        if (_currentDraft != null && !_isClearing) {
          state = DraftSaveStatus.idle;
        }
        return false;
      }

      state = DraftSaveStatus.saving;
      final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
      await draftsNotifier.saveDraft(updatedDraft);

      // Only update state if not cleared during await
      if (_currentDraft != null && !_isClearing) {
        _lastSavedAt = updatedDraft.lastModified;
        state = DraftSaveStatus.saved;
        _scheduleStatusReset();
      }
      return true;
    } catch (e) {
      // Only set error state if not cleared
      if (_currentDraft != null && !_isClearing) {
        state = DraftSaveStatus.error;
      }
      return false;
    }
  }

  /// Reset saved -> idle after a short delay, without blocking the caller.
  /// Guarded defensively in case the notifier was disposed while waiting.
  void _scheduleStatusReset() {
    Future.delayed(const Duration(seconds: 2), () {
      try {
        if (state == DraftSaveStatus.saved) {
          state = DraftSaveStatus.idle;
        }
      } catch (_) {
        // Notifier was disposed while waiting - nothing to reset
      }
    });
  }

  /// Delete the stored record for [draftId] if one exists
  Future<void> _deleteStoredDraftIfExists(String draftId) async {
    final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
    if (draftsNotifier.getDraft(draftId) != null) {
      await draftsNotifier.deleteDraft(draftId);
      _lastSavedAt = null;
    }
  }

  /// Force save immediately (used on app background)
  ///
  /// Same contract as [updateAndSave]: returns true only when the draft
  /// was actually persisted; empty content deletes any stored record.
  Future<bool> forceSave({
    required String title,
    required String bodyContent,
  }) async {
    if (_currentDraft == null || _isClearing) return false;

    final updatedDraft = _currentDraft!.copyWith(
      title: title,
      bodyContent: bodyContent,
      lastModified: DateTime.now(),
    );
    _currentDraft = updatedDraft;

    // Empty content: delete any stored record instead of skipping
    if (!updatedDraft.hasContent) {
      await _deleteStoredDraftIfExists(updatedDraft.id);
      return false;
    }

    final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
    await draftsNotifier.saveDraft(updatedDraft);
    // Only update _lastSavedAt if _currentDraft wasn't cleared during await
    if (_currentDraft != null) {
      _lastSavedAt = updatedDraft.lastModified;
    }
    return true;
  }

  /// Clear current draft after successful publish
  Future<void> clearAfterPublish() async {
    if (_currentDraft == null) return;

    // Clear the session and raise the flag BEFORE awaiting so an in-flight
    // debounced autosave can't resurrect the deleted draft
    _isClearing = true;
    final draftId = _currentDraft!.id;
    _currentDraft = null;
    _lastSavedAt = null;
    state = DraftSaveStatus.idle;

    try {
      final draftsNotifier = ref.read(draftsNotifierProvider.notifier);
      await draftsNotifier.deleteDraft(draftId);
    } finally {
      _isClearing = false;
    }
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
