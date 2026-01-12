import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/github_repo.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'folder_browser_screen.dart';

class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen>
    with SingleTickerProviderStateMixin {
  GitHubRepo? _selectedRepo;
  final _assetsPathController = TextEditingController(text: 'assets/images');
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _assetsPathController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRepo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a repository')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ref.read(configNotifierProvider.notifier).saveConfig(
            repoOwner: _selectedRepo!.ownerLogin,
            repoName: _selectedRepo!.name,
            branch: _selectedRepo!.defaultBranch,
            assetsPath: _assetsPathController.text.trim(),
          );

      if (mounted) {
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final reposAsync = ref.watch(userReposProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(user?.login),
                            const SizedBox(height: 40),
                            _buildRepoSelector(reposAsync),
                            const SizedBox(height: 24),
                            _buildAssetsPathInput(),
                            const SizedBox(height: 40),
                            _buildSaveButton(),
                            const SizedBox(height: 16),
                            _buildLogoutButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String? username) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF2D4A3E).withAlpha(60),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE8A87C).withAlpha(30),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.settings_rounded,
            size: 32,
            color: Color(0xFFE8A87C),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Configure Your Blog',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select your Jekyll repository and set up the image path.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (username != null) ...[
          const SizedBox(height: 4),
          Text(
            'Logged in as @$username',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFE8A87C),
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildRepoSelector(AsyncValue<List<GitHubRepo>> reposAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repository',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: AppTheme.cardGlow,
          child: reposAsync.when(
            loading: () => Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF162A1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF2D4A3E).withAlpha(80),
                ),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFE8A87C),
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Loading repositories...',
                    style: TextStyle(
                      color: Color(0xFFA8B5A0),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            error: (error, stack) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: const Color(0xFF162A1E),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE57373).withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFE57373),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to load repos: $error',
                      style: const TextStyle(
                        color: Color(0xFFE57373),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    color: const Color(0xFFE8A87C),
                    onPressed: () => ref.invalidate(userReposProvider),
                  ),
                ],
              ),
            ),
            data: (repos) => DropdownButtonFormField<GitHubRepo>(
              value: _selectedRepo,
              decoration: InputDecoration(
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 16, right: 12),
                  child: Icon(
                    Icons.folder_rounded,
                    color: Color(0xFFE8A87C),
                    size: 22,
                  ),
                ),
                hintText: 'Select your blog repository',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: const Color(0xFF2D4A3E).withAlpha(80),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFE8A87C),
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFF162A1E),
              ),
              dropdownColor: const Color(0xFF1A2F23),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFFA8B5A0),
              ),
              isExpanded: true,
              items: repos.map((repo) {
                return DropdownMenuItem<GitHubRepo>(
                  value: repo,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          repo.name,
                          style: const TextStyle(
                            color: Color(0xFFF5F5F0),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (repo.isPrivate)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8A87C).withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Private',
                            style: TextStyle(
                              color: Color(0xFFE8A87C),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (repo) {
                setState(() => _selectedRepo = repo);
              },
              validator: (value) {
                if (value == null) {
                  return 'Please select a repository';
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the repository that contains your Jekyll blog.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
              ),
        ),
      ],
    );
  }

  Future<void> _openFolderBrowser() async {
    if (_selectedRepo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a repository first'),
          backgroundColor: Color(0xFFE8A87C),
        ),
      );
      return;
    }

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => FolderBrowserScreen(
          repoOwner: _selectedRepo!.ownerLogin,
          repoName: _selectedRepo!.name,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        // If empty string (root), use a sensible default
        _assetsPathController.text = result.isEmpty ? 'assets/images' : result;
      });
      HapticFeedback.selectionClick();
    }
  }

  Widget _buildAssetsPathInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Image Assets Path',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: AppTheme.cardGlow,
                child: TextFormField(
                  controller: _assetsPathController,
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'monospace',
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 16, right: 12),
                      child: Icon(
                        Icons.image_rounded,
                        color: Color(0xFFE8A87C),
                        size: 22,
                      ),
                    ),
                    hintText: 'assets/images',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: const Color(0xFF2D4A3E).withAlpha(80),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFE8A87C),
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF162A1E),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the assets path';
                    }
                    // Remove leading/trailing slashes for validation
                    final cleaned = value.trim().replaceAll(RegExp(r'^/|/$'), '');
                    if (cleaned.isEmpty) {
                      return 'Invalid path';
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE8A87C).withAlpha(20),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: const Color(0xFF1A2F23),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: _openFolderBrowser,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE8A87C).withAlpha(60),
                      ),
                    ),
                    child: const Icon(
                      Icons.folder_open_rounded,
                      color: Color(0xFFE8A87C),
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Folder where images will be uploaded. Tap the folder icon to browse.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
              ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveConfiguration,
        child: _isSaving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF0D1B14),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.save_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Save Configuration'),
                ],
              ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          ref.read(authNotifierProvider.notifier).logout();
        },
        icon: const Icon(
          Icons.logout_rounded,
          size: 18,
          color: Color(0xFFA8B5A0),
        ),
        label: const Text(
          'Use different account',
          style: TextStyle(color: Color(0xFFA8B5A0)),
        ),
      ),
    );
  }
}
