import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_config.dart';
import '../../../core/models/blog_post.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/config_provider.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

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
  }

  @override
  void dispose() {
    _animController.dispose();
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final configState = ref.watch(configNotifierProvider);
    final postsState = ref.watch(postsNotifierProvider);

    final user = authState is AuthAuthenticated ? authState.user : null;
    final config = configState is ConfigLoaded ? configState.config : null;

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(
              children: [
                _buildHeader(context, ref, user, config),
                Expanded(
                  child: _buildContent(postsState),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
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
}
