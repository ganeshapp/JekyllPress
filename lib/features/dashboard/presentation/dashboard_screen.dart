import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_config.dart';
import '../../../core/models/blog_post.dart';
import '../../../core/models/local_draft.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/providers/drafts_provider.dart';
import '../../../core/providers/posts_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../about/presentation/about_screen.dart';
import '../../editor/presentation/editor_screen.dart';
import '../widgets/post_card.dart';
import '../widgets/empty_posts_view.dart';

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
    super.dispose();
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    await ref.read(postsNotifierProvider.notifier).refresh();
  }

  void _navigateToEditor([BlogPost? post]) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => EditorScreen(post: post),
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final configState = ref.watch(configNotifierProvider);
    final postsState = ref.watch(postsNotifierProvider);
    final draftsState = ref.watch(draftsNotifierProvider);

    final user = authState is AuthAuthenticated ? authState.user : null;
    final config = configState is ConfigLoaded ? configState.config : null;
    final draftsCount = draftsState.drafts.length;

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(
              children: [
                _buildHeader(context, ref, user, config),
                _buildTabBar(draftsCount),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildContent(postsState),
                      _buildDraftsContent(draftsState),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildTabBar(int draftsCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF162A1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2D4A3E).withAlpha(80),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: const Color(0xFFE8A87C),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: const Color(0xFF0D1B14),
        unselectedLabelColor: const Color(0xFFA8B5A0),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          const Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_done_rounded, size: 18),
                SizedBox(width: 8),
                Text('Published'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_note_rounded, size: 18),
                const SizedBox(width: 8),
                const Text('Drafts'),
                if (draftsCount > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8A87C).withAlpha(40),
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          if (user != null)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFE8A87C).withAlpha(50),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(user.avatarUrl),
                backgroundColor: const Color(0xFF2D4A3E),
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
                        config?.repoName ?? 'Blog',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRefreshing) ...[
                      const SizedBox(width: 10),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFE8A87C),
                        ),
                      ),
                    ],
                  ],
                ),
                if (config != null)
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
            icon: const Icon(Icons.refresh_rounded),
            color: const Color(0xFFA8B5A0),
            onPressed: _onRefresh,
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: Color(0xFFA8B5A0),
            ),
            color: const Color(0xFF1A2F23),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change_repo',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Change Repository'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('About'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(configNotifierProvider.notifier).clearConfig();
                await ref.read(authNotifierProvider.notifier).logout();
              } else if (value == 'change_repo') {
                await ref.read(configNotifierProvider.notifier).clearConfig();
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

  Widget _buildContent(PostsState postsState) {
    return switch (postsState) {
      PostsInitial() => _buildLoadingView(),
      PostsLoading(cachedPosts: final cached) => cached.isEmpty
          ? _buildLoadingView()
          : _buildPostsList(cached, isLoading: true),
      PostsLoaded(posts: final posts) => posts.isEmpty
          ? const EmptyPostsView()
          : _buildPostsList(posts),
      PostsError(message: final msg, cachedPosts: final cached) => cached.isEmpty
          ? _buildErrorView(msg)
          : _buildPostsList(cached, errorMessage: msg),
    };
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xFFE8A87C),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading posts...',
            style: TextStyle(
              color: Color(0xFFA8B5A0),
              fontSize: 14,
            ),
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
                color: const Color(0xFFE57373).withAlpha(20),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Color(0xFFE57373),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Failed to load posts',
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
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostsList(
    List<BlogPost> posts, {
    bool isLoading = false,
    String? errorMessage,
  }) {
    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: const Color(0xFFE8A87C),
      backgroundColor: const Color(0xFF1A2F23),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: posts.length + (errorMessage != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (errorMessage != null && index == 0) {
            return _buildSyncErrorBanner(errorMessage);
          }
          
          final postIndex = errorMessage != null ? index - 1 : index;
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
            child: PostCard(
              post: post,
              onTap: () => _navigateToEditor(post),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSyncErrorBanner(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE57373).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE57373).withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.sync_problem_rounded,
            color: Color(0xFFE57373),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Sync failed. Showing cached data.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFE57373),
                    fontSize: 13,
                  ),
            ),
          ),
          TextButton(
            onPressed: _onRefresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () => _navigateToEditor(),
      backgroundColor: const Color(0xFFE8A87C),
      foregroundColor: const Color(0xFF0D1B14),
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: const Text(
        'New Post',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDraftsContent(DraftsState draftsState) {
    if (draftsState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFE8A87C),
        ),
      );
    }

    if (draftsState.drafts.isEmpty) {
      return _buildEmptyDraftsView();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: draftsState.drafts.length,
      itemBuilder: (context, index) {
        final draft = draftsState.drafts[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: _buildDraftCard(draft),
        );
      },
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
              color: const Color(0xFF2D4A3E).withAlpha(30),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.drafts_rounded,
              size: 56,
              color: const Color(0xFFA8B5A0).withAlpha(120),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No drafts yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFF5F5F0),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your unsaved posts will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFA8B5A0),
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
              color: const Color(0xFF162A1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF2D4A3E).withAlpha(80),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isEditingExisting
                            ? const Color(0xFF4DB6AC).withAlpha(30)
                            : const Color(0xFFE8A87C).withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isEditingExisting ? Icons.edit_rounded : Icons.fiber_new_rounded,
                            size: 12,
                            color: isEditingExisting
                                ? const Color(0xFF4DB6AC)
                                : const Color(0xFFE8A87C),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isEditingExisting ? 'Editing' : 'New',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isEditingExisting
                                  ? const Color(0xFF4DB6AC)
                                  : const Color(0xFFE8A87C),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFA8B5A0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete button
                    GestureDetector(
                      onTap: () => _confirmDeleteDraft(draft),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: Color(0xFFA8B5A0),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  draft.title.isEmpty ? 'Untitled' : draft.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: draft.title.isEmpty
                        ? const Color(0xFFA8B5A0)
                        : const Color(0xFFF5F5F0),
                    fontStyle: draft.title.isEmpty ? FontStyle.italic : FontStyle.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (draft.excerpt.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    draft.excerpt,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFFA8B5A0),
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
        backgroundColor: const Color(0xFF1A2F23),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Delete Draft?'),
        content: Text(
          'Delete "${draft.title.isEmpty ? 'Untitled' : draft.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE57373),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(draftsNotifierProvider.notifier).deleteDraft(draft.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft deleted'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
