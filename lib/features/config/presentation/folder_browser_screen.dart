import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/folder_browser_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/desktop_content_width.dart';
import '../../../l10n/l10n.dart';

/// Clean and validate a user-typed new-folder path relative to
/// [basePath]. Returns the full repo-relative path, or null when the
/// input is empty or contains invalid segments ('.', '..', blanks).
String? joinNewFolderPath(String basePath, String input) {
  final cleaned = input.trim().replaceAll(RegExp(r'^/+|/+$'), '');
  if (cleaned.isEmpty) return null;

  final segments = cleaned.split('/').map((s) => s.trim()).toList();
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.' || segment == '..') return null;
  }

  final normalized = segments.join('/');
  return basePath.isEmpty ? normalized : '$basePath/$normalized';
}

/// Screen for browsing folders in a GitHub repository
class FolderBrowserScreen extends ConsumerStatefulWidget {
  final String repoOwner;
  final String repoName;

  /// Branch to browse; null uses the repo default branch
  final String? branch;
  final String? initialPath;

  const FolderBrowserScreen({
    super.key,
    required this.repoOwner,
    required this.repoName,
    this.branch,
    this.initialPath,
  });

  @override
  ConsumerState<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends ConsumerState<FolderBrowserScreen> {
  final _newFolderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize the folder browser after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(folderBrowserNotifierProvider.notifier);
      await notifier.initialize(
        repoOwner: widget.repoOwner,
        repoName: widget.repoName,
        branch: widget.branch,
      );
      // Open at the currently configured folder, if any
      final initialPath = widget.initialPath;
      if (initialPath != null && initialPath.isNotEmpty && mounted) {
        await notifier.navigateToFolder(initialPath);
      }
    });
  }

  @override
  void dispose() {
    _newFolderController.dispose();
    super.dispose();
  }

  void _selectCurrentFolder() {
    final state = ref.read(folderBrowserNotifierProvider);
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(state.currentPath);
  }

  void _navigateToFolder(RepoFolder folder) {
    HapticFeedback.selectionClick();
    ref.read(folderBrowserNotifierProvider.notifier).navigateToFolder(folder.path);
  }

  void _navigateUp() {
    HapticFeedback.selectionClick();
    ref.read(folderBrowserNotifierProvider.notifier).navigateUp();
  }

  /// Type a folder path that doesn't exist yet. GitHub has no empty
  /// directories - the folder is created implicitly on first upload -
  /// so this simply returns the typed path as the selection.
  Future<void> _promptNewFolder() async {
    final state = ref.read(folderBrowserNotifierProvider);
    _newFolderController.clear();

    final input = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.newFolderDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _newFolderController,
              autofocus: true,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: context.l10n.newFolderHint,
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
            const SizedBox(height: 12),
            Text(
              state.isAtRoot
                  ? context.l10n.newFolderHelpRoot
                  : context.l10n.newFolderHelpPath(state.currentPath),
              style: context.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _newFolderController.text),
            child: Text(context.l10n.useFolder),
          ),
        ],
      ),
    );

    if (input == null || !mounted) return;
    final path = joinNewFolderPath(state.currentPath, input);
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.enterValidFolderName)),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(path);
  }

  @override
  Widget build(BuildContext context) {
    final browserState = ref.watch(folderBrowserNotifierProvider);

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient(context),
        child: SafeArea(
          child: DesktopContentWidth(
            child: Column(
              children: [
                _buildHeader(browserState),
                _buildBreadcrumb(browserState),
                Expanded(
                  child: _buildFolderList(browserState),
                ),
                _buildSelectButton(browserState),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FolderBrowserState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            tooltip: context.l10n.commonCancel,
            style: IconButton.styleFrom(
              foregroundColor: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.selectFolderTitle,
              style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          IconButton(
            onPressed: state.isLoading
                ? null
                : ref.read(folderBrowserNotifierProvider.notifier).refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refreshFoldersTooltip,
            style: IconButton.styleFrom(
              foregroundColor: context.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            onPressed: _promptNewFolder,
            icon: const Icon(Icons.create_new_folder_rounded),
            tooltip: context.l10n.newFolderTooltip,
            style: IconButton.styleFrom(
              foregroundColor: context.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(FolderBrowserState state) {
    final scheme = context.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outline.withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          Icon(
            state.isAtRoot ? Icons.home_rounded : Icons.folder_rounded,
            color: scheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.isAtRoot ? '/' : '/${state.currentPath}',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: scheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!state.isAtRoot)
            IconButton(
              onPressed: _navigateUp,
              icon: const Icon(Icons.arrow_upward_rounded),
              tooltip: context.l10n.goUpTooltip,
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              style: IconButton.styleFrom(
                foregroundColor: scheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFolderList(FolderBrowserState state) {
    final scheme = context.colorScheme;
    if (state.isLoading && state.folders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: scheme.error,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: TextStyle(color: scheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  ref.read(folderBrowserNotifierProvider.notifier).refresh();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (state.folders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_rounded,
                color: scheme.onSurfaceVariant.withAlpha(150),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.noSubfolders,
                style: context.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.noSubfoldersBody,
                style: context.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withAlpha(180),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(folderBrowserNotifierProvider.notifier).refresh();
      },
      color: scheme.primary,
      backgroundColor: scheme.surfaceContainerHigh,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.folders.length,
        itemBuilder: (context, index) {
          final folder = state.folders[index];
          return _buildFolderTile(folder);
        },
      ),
    );
  }

  Widget _buildFolderTile(RepoFolder folder) {
    final scheme = context.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outline.withAlpha(60),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToFolder(folder),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.folder_rounded,
                    color: scheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    folder.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectButton(FolderBrowserState state) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(
            color: scheme.outline.withAlpha(60),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.selectedPathLabel,
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              state.isAtRoot
                  ? context.l10n.repositoryRootLabel
                  : state.currentPath,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: scheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: state.isLoading ? null : _selectCurrentFolder,
                icon: const Icon(Icons.check_rounded, size: 20),
                label: Text(context.l10n.selectThisFolder),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
