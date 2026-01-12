import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/folder_browser_provider.dart';
import '../../../core/theme/app_theme.dart';

/// Screen for browsing folders in a GitHub repository
class FolderBrowserScreen extends ConsumerStatefulWidget {
  final String repoOwner;
  final String repoName;
  final String? initialPath;

  const FolderBrowserScreen({
    super.key,
    required this.repoOwner,
    required this.repoName,
    this.initialPath,
  });

  @override
  ConsumerState<FolderBrowserScreen> createState() => _FolderBrowserScreenState();
}

class _FolderBrowserScreenState extends ConsumerState<FolderBrowserScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize the folder browser after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(folderBrowserNotifierProvider.notifier).initialize(
            repoOwner: widget.repoOwner,
            repoName: widget.repoName,
          );
    });
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

  @override
  Widget build(BuildContext context) {
    final browserState = ref.watch(folderBrowserNotifierProvider);

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
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
            tooltip: 'Cancel',
            style: IconButton.styleFrom(
              foregroundColor: const Color(0xFFA8B5A0),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Select Folder',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (state.isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFE8A87C),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(FolderBrowserState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF162A1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2D4A3E).withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          Icon(
            state.isAtRoot ? Icons.home_rounded : Icons.folder_rounded,
            color: const Color(0xFFE8A87C),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              state.isAtRoot ? '/' : '/${state.currentPath}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Color(0xFFF5F5F0),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!state.isAtRoot)
            IconButton(
              onPressed: _navigateUp,
              icon: const Icon(Icons.arrow_upward_rounded),
              tooltip: 'Go up',
              iconSize: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFFE8A87C),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFolderList(FolderBrowserState state) {
    if (state.isLoading && state.folders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE8A87C),
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE57373),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: const TextStyle(color: Color(0xFFE57373)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  ref.read(folderBrowserNotifierProvider.notifier).refresh();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
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
                color: const Color(0xFFA8B5A0).withAlpha(150),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'No subfolders',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: const Color(0xFFA8B5A0),
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'This folder has no subfolders.\nYou can select this folder or go back.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFA8B5A0).withAlpha(180),
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
      color: const Color(0xFFE8A87C),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F23),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2D4A3E).withAlpha(60),
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
                    color: const Color(0xFFE8A87C).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.folder_rounded,
                    color: Color(0xFFE8A87C),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    folder.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFF5F5F0),
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFA8B5A0),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B14),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF2D4A3E).withAlpha(60),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Selected path:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFA8B5A0),
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              state.isAtRoot ? '(repository root)' : state.currentPath,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Color(0xFFE8A87C),
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
                label: const Text('Select This Folder'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
