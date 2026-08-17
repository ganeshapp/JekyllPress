import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/app_config.dart';
import '../../../core/models/github_repo.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/repositories/repo_repository.dart';
import '../../../core/services/content_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import 'folder_browser_screen.dart';

// Palette shared by every section (matches AppTheme)
const _accent = Color(0xFFE8A87C);
const _fieldFill = Color(0xFF162A1E);
const _borderGreen = Color(0xFF2D4A3E);
const _textPrimary = Color(0xFFF5F5F0);
const _textSecondary = Color(0xFFA8B5A0);
const _errorRed = Color(0xFFE57373);

/// Split a comma-separated input into trimmed, non-empty values
List<String> parseCommaList(String input) => input
    .split(',')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// Parse a manually entered repository as `owner/name`, tolerating a
/// full github.com URL, a git@ remote, or a trailing `.git`. Returns
/// null when the input is not a valid owner/name pair.
({String owner, String name})? parseOwnerRepo(String input) {
  var s = input.trim();
  s = s.replaceFirst(RegExp(r'^https?://(www\.)?github\.com/'), '');
  s = s.replaceFirst(RegExp(r'^git@github\.com:'), '');
  if (s.endsWith('.git')) {
    s = s.substring(0, s.length - 4);
  }
  s = s.replaceAll(RegExp(r'^/+|/+$'), '');

  final parts = s.split('/');
  if (parts.length != 2) return null;
  final owner = parts[0].trim();
  final name = parts[1].trim();
  if (owner.isEmpty || name.isEmpty) return null;

  // GitHub owner/repo names: alphanumerics, hyphens, underscores, dots
  final valid = RegExp(r'^[A-Za-z0-9._-]+$');
  if (!valid.hasMatch(owner) || !valid.hasMatch(name)) return null;
  return (owner: owner, name: name);
}

class ConfigScreen extends ConsumerStatefulWidget {
  /// When set, the screen edits an existing configuration (opened from
  /// the dashboard) and pops with `true` after a successful save,
  /// instead of being the first-run setup screen.
  final AppConfig? initialConfig;

  const ConfigScreen({super.key, this.initialConfig});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen>
    with SingleTickerProviderStateMixin {
  GitHubRepo? _selectedRepo;
  String? _selectedBranch;

  // Manual owner/name entry (for repos the paginated listing misses)
  bool _manualRepoMode = false;
  bool _isFetchingManualRepo = false;
  final _manualRepoController = TextEditingController();

  // Jekyll detection banner
  JekyllRepoCheck? _jekyllCheck;
  bool _isCheckingJekyll = false;
  String _jekyllCheckedPostsPath = '_posts';
  int _jekyllCheckSeq = 0;

  final _postsPathController = TextEditingController(text: '_posts');
  final _draftsPathController = TextEditingController(text: '_drafts');
  final _assetsPathController = TextEditingController(text: 'assets/images');
  final _siteUrlController = TextEditingController();
  final _baseurlController = TextEditingController();
  final _layoutController = TextEditingController();
  final _categoriesController = TextEditingController();
  final _tagsController = TextEditingController();

  /// Content dirs beyond the posts folder (Jekyll collections)
  List<String> _extraContentDirs = [];

  /// Last values written by [inferPagesSite] - a field still equal to
  /// its inferred value is re-inferred when the repo changes
  String? _inferredSiteUrl;
  String? _inferredBaseurl;

  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  bool get _isEditMode => widget.initialConfig != null;

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

    final config = widget.initialConfig;
    if (config != null) {
      _postsPathController.text = config.postsPath;
      _draftsPathController.text = config.draftsPath;
      _assetsPathController.text = config.assetsPath;
      _siteUrlController.text = config.siteUrl;
      _baseurlController.text = config.baseurl;
      _layoutController.text = config.defaultLayout ?? '';
      _categoriesController.text = config.defaultCategories.join(', ');
      _tagsController.text = config.defaultTags.join(', ');
      _extraContentDirs =
          config.contentDirs.where((d) => d != config.postsPath).toList();
      _selectedBranch = config.branch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prefillRepo(config);
      });
    }
  }

  @override
  void dispose() {
    _manualRepoController.dispose();
    _postsPathController.dispose();
    _draftsPathController.dispose();
    _assetsPathController.dispose();
    _siteUrlController.dispose();
    _baseurlController.dispose();
    _layoutController.dispose();
    _categoriesController.dispose();
    _tagsController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String _cleanPath(String value) => ContentService.cleanDir(value.trim());

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Resolve the saved repo into a [GitHubRepo] so the dropdown, branch
  /// list, and Jekyll check work when editing an existing config
  Future<void> _prefillRepo(AppConfig config) async {
    GitHubRepo? repo;
    try {
      final repos = await ref.read(userReposProvider.future);
      for (final r in repos) {
        if (r.ownerLogin.toLowerCase() == config.repoOwner.toLowerCase() &&
            r.name.toLowerCase() == config.repoName.toLowerCase()) {
          repo = r;
          break;
        }
      }
      if (repo == null && mounted) {
        repo = await ref.read(repoRepositoryProvider).getRepo(
              repoOwner: config.repoOwner,
              repoName: config.repoName,
            );
      }
    } catch (_) {
      repo = null;
    }
    if (!mounted) return;

    if (repo == null) {
      // Could not resolve (offline, revoked access): keep the saved name
      // visible in the manual field so the user is not left blank
      setState(() {
        _manualRepoMode = true;
        _manualRepoController.text =
            '${config.repoOwner}/${config.repoName}';
      });
      return;
    }

    setState(() => _selectedRepo = repo);
    // Track the inference only if the saved fields still match it, so an
    // untouched inferred URL keeps following the repo but a customized
    // one is never overwritten
    final inferred = inferPagesSite(
      repoOwner: repo.ownerLogin,
      repoName: repo.name,
    );
    if (_siteUrlController.text.trim() == inferred.siteUrl) {
      _inferredSiteUrl = inferred.siteUrl;
    }
    if (_baseurlController.text.trim() == inferred.baseurl) {
      _inferredBaseurl = inferred.baseurl;
    }
    _runJekyllCheck();
  }

  /// Select [repo] (from the dropdown or a manual fetch): reset the
  /// branch to its default, re-infer untouched site fields, and re-run
  /// the Jekyll check
  void _selectRepo(GitHubRepo repo) {
    setState(() {
      _selectedRepo = repo;
      _selectedBranch = repo.defaultBranch;
      _jekyllCheck = null;
    });
    _inferSiteFields(repo);
    _runJekyllCheck();
  }

  /// Pre-fill site URL / baseurl from the GitHub Pages convention when
  /// the fields are empty or still hold a previous inference
  void _inferSiteFields(GitHubRepo repo) {
    final inferred = inferPagesSite(
      repoOwner: repo.ownerLogin,
      repoName: repo.name,
    );
    final siteText = _siteUrlController.text.trim();
    if (siteText.isEmpty || siteText == _inferredSiteUrl) {
      _siteUrlController.text = inferred.siteUrl;
      final baseText = _baseurlController.text.trim();
      if (baseText == (_inferredBaseurl ?? '')) {
        _baseurlController.text = inferred.baseurl;
        _inferredBaseurl = inferred.baseurl;
      }
      _inferredSiteUrl = inferred.siteUrl;
    }
  }

  Future<void> _runJekyllCheck() async {
    final repo = _selectedRepo;
    if (repo == null) return;
    final branch = _selectedBranch ?? repo.defaultBranch;
    final postsPath = _cleanPath(_postsPathController.text);
    final checkedPostsPath = postsPath.isEmpty ? '_posts' : postsPath;

    final seq = ++_jekyllCheckSeq;
    setState(() {
      _isCheckingJekyll = true;
      _jekyllCheck = null;
      _jekyllCheckedPostsPath = checkedPostsPath;
    });

    JekyllRepoCheck result;
    try {
      result = await ref.read(repoRepositoryProvider).isJekyllRepo(
            repo,
            postsPath: checkedPostsPath,
            branch: branch,
          );
    } catch (_) {
      result = JekyllRepoCheck.couldNotVerify;
    }

    if (!mounted || seq != _jekyllCheckSeq) return;
    setState(() {
      _isCheckingJekyll = false;
      _jekyllCheck = result;
    });
  }

  Future<void> _useManualRepo() async {
    final parsed = parseOwnerRepo(_manualRepoController.text);
    if (parsed == null) {
      _showSnack('Enter the repository as owner/name');
      return;
    }

    setState(() => _isFetchingManualRepo = true);
    try {
      final repo = await ref.read(repoRepositoryProvider).getRepo(
            repoOwner: parsed.owner,
            repoName: parsed.name,
          );
      if (!mounted) return;
      _selectRepo(repo);
      HapticFeedback.selectionClick();
    } catch (e) {
      if (mounted) _showSnack('$e');
    } finally {
      if (mounted) setState(() => _isFetchingManualRepo = false);
    }
  }

  Future<String?> _pickFolder({String? initialPath}) async {
    final repo = _selectedRepo;
    if (repo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a repository first'),
          backgroundColor: _accent,
        ),
      );
      return null;
    }

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => FolderBrowserScreen(
          repoOwner: repo.ownerLogin,
          repoName: repo.name,
          branch: _selectedBranch ?? repo.defaultBranch,
          initialPath: initialPath,
        ),
      ),
    );

    if (result != null) HapticFeedback.selectionClick();
    return result;
  }

  /// Browse into [controller]'s folder; root selection falls back to
  /// [rootFallback]. Re-runs the Jekyll check when the posts dir moved.
  Future<void> _browsePathInto(
    TextEditingController controller,
    String rootFallback, {
    bool recheckJekyll = false,
  }) async {
    final result =
        await _pickFolder(initialPath: _cleanPath(controller.text));
    if (result == null || !mounted) return;
    setState(() {
      controller.text = result.isEmpty ? rootFallback : result;
    });
    if (recheckJekyll) _runJekyllCheck();
  }

  Future<void> _addContentDir() async {
    final result = await _pickFolder();
    if (result == null || !mounted) return;
    final dir = ContentService.cleanDir(result);
    if (dir.isEmpty) {
      _showSnack('The repository root cannot be a content folder');
      return;
    }
    final postsPath = _cleanPath(_postsPathController.text);
    if (dir == postsPath || _extraContentDirs.contains(dir)) return;
    setState(() => _extraContentDirs.add(dir));
  }

  /// Editing an existing config onto a different repo/branch removes
  /// repo-scoped local data - confirm first (never silently)
  Future<bool> _confirmRepoSwitch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2F23),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Change Repository?'),
        content: const Text(
          'Drafts and cached posts are specific to the current repository '
          'and branch, and will be removed. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: _errorRed,
            ),
            child: const Text('Change'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = _selectedRepo;
    if (repo == null) {
      _showSnack('Please select a repository');
      return;
    }
    final branch = _selectedBranch ?? repo.defaultBranch;

    final initial = widget.initialConfig;
    if (initial != null &&
        (initial.repoOwner != repo.ownerLogin ||
            initial.repoName != repo.name ||
            initial.branch != branch)) {
      if (!await _confirmRepoSwitch()) return;
      if (!mounted) return;
    }

    setState(() => _isSaving = true);

    try {
      final postsPath = _cleanPath(_postsPathController.text);
      final contentDirs = <String>[
        postsPath,
        ..._extraContentDirs.where((d) => d != postsPath),
      ];
      // Keep the active dir across edits when it still exists
      final activeContentDir = (initial != null &&
              contentDirs.contains(initial.activeContentDir))
          ? initial.activeContentDir
          : postsPath;
      final layout = _layoutController.text.trim();

      await ref.read(configNotifierProvider.notifier).saveConfig(
            repoOwner: repo.ownerLogin,
            repoName: repo.name,
            branch: branch,
            assetsPath: _cleanPath(_assetsPathController.text),
            postsPath: postsPath,
            draftsPath: _cleanPath(_draftsPathController.text),
            siteUrl: _siteUrlController.text.trim(),
            baseurl: _baseurlController.text.trim(),
            defaultLayout: layout.isEmpty ? null : layout,
            defaultCategories: parseCommaList(_categoriesController.text),
            defaultTags: parseCommaList(_tagsController.text),
            contentDirs: contentDirs.length > 1 ? contentDirs : null,
            activeContentDir: activeContentDir,
          );

      if (mounted) {
        HapticFeedback.mediumImpact();
        if (_isEditMode) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Failed to save: $e');
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
                            const SizedBox(height: 32),
                            _buildSectionTitle('REPOSITORY'),
                            _buildRepoSection(reposAsync),
                            const SizedBox(height: 28),
                            _buildSectionTitle('BRANCH'),
                            _buildBranchSection(),
                            const SizedBox(height: 28),
                            _buildSectionTitle('CONTENT'),
                            _buildContentSection(),
                            const SizedBox(height: 28),
                            _buildSectionTitle('SITE'),
                            _buildSiteSection(),
                            const SizedBox(height: 28),
                            _buildSectionTitle('FRONT MATTER DEFAULTS'),
                            _buildFrontMatterSection(),
                            const SizedBox(height: 40),
                            _buildSaveButton(),
                            const SizedBox(height: 16),
                            if (_isEditMode)
                              _buildCancelButton()
                            else
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
            color: _borderGreen.withAlpha(60),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _accent.withAlpha(30),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.settings_rounded,
            size: 32,
            color: _accent,
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
          'Connect your Jekyll repository and tune how posts are published.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (username != null) ...[
          const SizedBox(height: 4),
          Text(
            'Logged in as @$username',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _accent,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          color: _accent.withAlpha(200),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({IconData? icon, String? hintText}) {
    return InputDecoration(
      prefixIcon: icon == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 16, right: 12),
              child: Icon(icon, color: _accent, size: 22),
            ),
      hintText: hintText,
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
          color: _borderGreen.withAlpha(80),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: _accent,
          width: 2,
        ),
      ),
      filled: true,
      fillColor: _fieldFill,
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }

  Widget _buildHelperText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
            ),
      ),
    );
  }

  // ---------------------------------------------------------------- REPO

  Widget _buildRepoSection(AsyncValue<List<GitHubRepo>> reposAsync) {
    final selected = _selectedRepo;
    final repos = reposAsync.valueOrNull ?? const <GitHubRepo>[];
    final selectedIsListed = selected != null && repos.contains(selected);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: AppTheme.cardGlow,
          child: reposAsync.when(
            loading: () => _buildRepoLoading(),
            error: (error, stack) => _buildRepoError(error),
            data: (repos) => _buildRepoDropdown(repos),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the repository that contains your Jekyll blog.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
              ),
        ),
        if (reposAsync.valueOrNull?.isEmpty ?? false) ...[
          const SizedBox(height: 12),
          _buildEmptyReposHint(),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              setState(() => _manualRepoMode = !_manualRepoMode);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: _textSecondary,
            ),
            child: Text(
              _manualRepoMode
                  ? 'Hide manual entry'
                  : "Can't see your repo? Enter owner/name manually",
              style: const TextStyle(
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: _textSecondary,
              ),
            ),
          ),
        ),
        if (_manualRepoMode) ...[
          const SizedBox(height: 8),
          _buildManualRepoEntry(),
        ],
        if (selected != null && !selectedIsListed) ...[
          const SizedBox(height: 12),
          _buildManualRepoBadge(selected),
        ],
        if (_isCheckingJekyll || _jekyllCheck != null) ...[
          const SizedBox(height: 12),
          _buildJekyllBanner(),
        ],
      ],
    );
  }

  Widget _buildRepoLoading() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _borderGreen.withAlpha(80),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _accent,
            ),
          ),
          SizedBox(width: 16),
          Text(
            'Loading repositories...',
            style: TextStyle(
              color: _textSecondary,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRepoError(Object error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _errorRed.withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _errorRed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Failed to load repos: $error',
              style: const TextStyle(
                color: _errorRed,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: _accent,
            onPressed: () => ref.invalidate(userReposProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildRepoDropdown(List<GitHubRepo> repos) {
    // The dropdown value must be one of its items - a manually entered
    // repo that isn't in the listing is shown as a badge below instead
    final selected = _selectedRepo;
    final dropdownValue =
        (selected != null && repos.contains(selected)) ? selected : null;

    return DropdownButtonFormField<GitHubRepo>(
      value: dropdownValue,
      decoration: _inputDecoration(
        icon: Icons.folder_rounded,
        hintText: 'Select your blog repository',
      ),
      dropdownColor: const Color(0xFF1A2F23),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: _textSecondary,
      ),
      isExpanded: true,
      items: repos.map((repo) {
        return DropdownMenuItem<GitHubRepo>(
          value: repo,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  repo.fullName,
                  style: const TextStyle(
                    color: _textPrimary,
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
                    color: _accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Private',
                    style: TextStyle(
                      color: _accent,
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
        if (repo != null) _selectRepo(repo);
      },
      validator: (value) {
        if (value == null && _selectedRepo == null) {
          return 'Please select a repository';
        }
        return null;
      },
    );
  }

  Widget _buildManualRepoEntry() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextFormField(
            controller: _manualRepoController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'monospace',
            ),
            decoration: _inputDecoration(
              icon: Icons.link_rounded,
              hintText: 'owner/repository',
            ),
            onFieldSubmitted: (_) => _useManualRepo(),
          ),
        ),
        const SizedBox(width: 12),
        _buildSquareIconButton(
          icon: Icons.check_rounded,
          isLoading: _isFetchingManualRepo,
          onTap: _isFetchingManualRepo ? null : _useManualRepo,
        ),
      ],
    );
  }

  Widget _buildManualRepoBadge(GitHubRepo repo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGreen.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_special_rounded, color: _accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Using ${repo.fullName}',
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Inline result of the Jekyll check. Informational only - saving is
  /// never blocked.
  Widget _buildJekyllBanner() {
    final (color, icon, message) = _isCheckingJekyll
        ? (
            _textSecondary,
            Icons.hourglass_top_rounded,
            'Checking for a Jekyll site...',
          )
        : switch (_jekyllCheck!) {
            JekyllRepoCheck.jekyll => (
                AppTheme.success,
                Icons.check_circle_rounded,
                'Jekyll site detected',
              ),
            JekyllRepoCheck.couldNotVerify => (
                _accent,
                Icons.help_outline_rounded,
                'Could not verify this is a Jekyll site - '
                    'you can continue anyway',
              ),
            JekyllRepoCheck.notJekyll => (
                _errorRed,
                Icons.warning_amber_rounded,
                'This does not look like a Jekyll repo '
                    '(no _config.yml or $_jekyllCheckedPostsPath)',
              ),
          };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(
        children: [
          if (_isCheckingJekyll)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _textSecondary,
              ),
            )
          else
            Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shown when GitHub returned zero repositories. For device-flow
  /// sessions the usual cause is that the GitHub App was authorized but
  /// never INSTALLED on the blog repo.
  Widget _buildEmptyReposHint() {
    final isDeviceAuth =
        ref.watch(authMethodProvider).valueOrNull == AuthMethods.device;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _accent.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _accent.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: _accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isDeviceAuth
                      ? 'No repositories found. A GitHub App only sees '
                          'repositories it is installed on - install it on '
                          'your blog repo, then refresh.'
                      : 'No repositories found for this account.',
                  style: const TextStyle(
                    color: _accent,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: _accent,
                onPressed: () => ref.invalidate(userReposProvider),
              ),
            ],
          ),
          if (isDeviceAuth) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse('https://github.com/settings/installations'),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Open GitHub App installations'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------- BRANCH

  Widget _buildBranchSection() {
    final repo = _selectedRepo;
    if (repo == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: _fieldFill.withAlpha(120),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _borderGreen.withAlpha(50),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.fork_right_rounded,
              color: _textSecondary,
              size: 22,
            ),
            SizedBox(width: 12),
            Text(
              'Select a repository first',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );
    }

    final branchesAsync = ref.watch(repoBranchesProvider(
      repoOwner: repo.ownerLogin,
      repoName: repo.name,
    ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: AppTheme.cardGlow,
          child: branchesAsync.when(
            loading: () => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: _fieldFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _borderGreen.withAlpha(80),
                ),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _accent,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Loading branches...',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            error: (error, stack) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: _fieldFill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _errorRed.withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: _errorRed,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Failed to load branches - using '
                      '"${_selectedBranch ?? repo.defaultBranch}"',
                      style: const TextStyle(
                        color: _errorRed,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    color: _accent,
                    onPressed: () => ref.invalidate(repoBranchesProvider(
                      repoOwner: repo.ownerLogin,
                      repoName: repo.name,
                    )),
                  ),
                ],
              ),
            ),
            data: (branches) => _buildBranchDropdown(repo, branches),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Branch posts are read from and published to.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
              ),
        ),
      ],
    );
  }

  Widget _buildBranchDropdown(GitHubRepo repo, List<String> branches) {
    final items = branches.isEmpty ? [repo.defaultBranch] : branches;
    final fallback =
        items.contains(repo.defaultBranch) ? repo.defaultBranch : items.first;
    final value = items.contains(_selectedBranch) ? _selectedBranch : fallback;

    // Keep the saved value in sync with what the dropdown shows (e.g.
    // the configured branch was deleted on GitHub)
    if (_selectedBranch != value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedBranch != value) {
          setState(() => _selectedBranch = value);
        }
      });
    }

    return DropdownButtonFormField<String>(
      value: value,
      decoration: _inputDecoration(icon: Icons.fork_right_rounded),
      dropdownColor: const Color(0xFF1A2F23),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: _textSecondary,
      ),
      isExpanded: true,
      items: items.map((branch) {
        return DropdownMenuItem<String>(
          value: branch,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  branch,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 15,
                    fontFamily: 'monospace',
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (branch == repo.defaultBranch)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'default',
                    style: TextStyle(
                      color: _accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
      onChanged: (branch) {
        if (branch == null || branch == _selectedBranch) return;
        setState(() => _selectedBranch = branch);
        _runJekyllCheck();
      },
    );
  }

  // ------------------------------------------------------------- CONTENT

  Widget _buildContentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPathField(
          label: 'Posts Folder',
          controller: _postsPathController,
          icon: Icons.article_rounded,
          hint: '_posts',
          helper: 'Folder your published Jekyll posts live in.',
          onBrowse: () => _browsePathInto(
            _postsPathController,
            '_posts',
            recheckJekyll: true,
          ),
          onSubmitted: (_) => _runJekyllCheck(),
        ),
        const SizedBox(height: 20),
        _buildPathField(
          label: 'Drafts Folder',
          controller: _draftsPathController,
          icon: Icons.edit_note_rounded,
          hint: '_drafts',
          helper: 'Folder Jekyll drafts are saved to.',
          onBrowse: () => _browsePathInto(_draftsPathController, '_drafts'),
        ),
        const SizedBox(height: 20),
        _buildContentDirsEditor(),
        const SizedBox(height: 20),
        _buildPathField(
          label: 'Image Assets Path',
          controller: _assetsPathController,
          icon: Icons.image_rounded,
          hint: 'assets/images',
          helper: 'Folder where images will be uploaded. '
              'Tap the folder icon to browse.',
          onBrowse: () =>
              _browsePathInto(_assetsPathController, 'assets/images'),
        ),
      ],
    );
  }

  Widget _buildPathField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required String helper,
    required VoidCallback onBrowse,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: AppTheme.cardGlow,
                child: TextFormField(
                  controller: controller,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: const TextStyle(
                    fontSize: 15,
                    fontFamily: 'monospace',
                  ),
                  decoration: _inputDecoration(icon: icon, hintText: hint),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter the ${label.toLowerCase()}';
                    }
                    if (_cleanPath(value).isEmpty) {
                      return 'Invalid path';
                    }
                    return null;
                  },
                  onFieldSubmitted: onSubmitted,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildSquareIconButton(
              icon: Icons.folder_open_rounded,
              onTap: onBrowse,
            ),
          ],
        ),
        _buildHelperText(helper),
      ],
    );
  }

  Widget _buildSquareIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: _accent.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF1A2F23),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _accent.withAlpha(60),
              ),
            ),
            child: isLoading
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accent,
                      ),
                    ),
                  )
                : Icon(icon, color: _accent, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildContentDirsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Additional Content Folders'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final dir in _extraContentDirs)
              InputChip(
                label: Text(dir),
                labelStyle: const TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                backgroundColor: _fieldFill,
                deleteIconColor: _textSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: _borderGreen.withAlpha(80)),
                ),
                onDeleted: () {
                  setState(() => _extraContentDirs.remove(dir));
                },
              ),
            ActionChip(
              avatar: const Icon(
                Icons.add_rounded,
                size: 18,
                color: _accent,
              ),
              label: const Text('Add folder'),
              labelStyle: const TextStyle(
                color: _accent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: _accent.withAlpha(15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: _accent.withAlpha(60)),
              ),
              onPressed: _addContentDir,
            ),
          ],
        ),
        _buildHelperText(
          'Jekyll collections you also publish to (e.g. _wiki, _projects). '
          'Switch between them from the dashboard.',
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- SITE

  Widget _buildSiteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('Site URL'),
        Container(
          decoration: AppTheme.cardGlow,
          child: TextFormField(
            controller: _siteUrlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'monospace',
            ),
            decoration: _inputDecoration(
              icon: Icons.public_rounded,
              hintText: 'https://username.github.io',
            ),
          ),
        ),
        _buildHelperText(
          'Public URL of your published site. Pre-filled from the GitHub '
          'Pages convention - change it if you use a custom domain.',
        ),
        const SizedBox(height: 20),
        _buildFieldLabel('Base URL'),
        Container(
          decoration: AppTheme.cardGlow,
          child: TextFormField(
            controller: _baseurlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'monospace',
            ),
            decoration: _inputDecoration(
              icon: Icons.subdirectory_arrow_right_rounded,
              hintText: '/repository-name',
            ),
          ),
        ),
        _buildHelperText(
          'Project pages are served under /<repo> '
          '(e.g. https://user.github.io/blog needs baseurl /blog) - image '
          'links are prefixed with it. Leave empty for user/org sites and '
          'custom domains served at the root.',
        ),
      ],
    );
  }

  // -------------------------------------------------------- FRONT MATTER

  Widget _buildFrontMatterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Leave empty to let your site's _config.yml defaults apply "
          '(recommended).',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
              ),
        ),
        const SizedBox(height: 16),
        _buildFieldLabel('Layout'),
        Container(
          decoration: AppTheme.cardGlow,
          child: TextFormField(
            controller: _layoutController,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'monospace',
            ),
            decoration: _inputDecoration(
              icon: Icons.view_quilt_rounded,
              hintText: 'post',
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildFieldLabel('Default Categories'),
        Container(
          decoration: AppTheme.cardGlow,
          child: TextFormField(
            controller: _categoriesController,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'monospace',
            ),
            decoration: _inputDecoration(
              icon: Icons.category_rounded,
              hintText: 'blog, notes (comma separated)',
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildFieldLabel('Default Tags'),
        Container(
          decoration: AppTheme.cardGlow,
          child: TextFormField(
            controller: _tagsController,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'monospace',
            ),
            decoration: _inputDecoration(
              icon: Icons.tag_rounded,
              hintText: 'jekyll, writing (comma separated)',
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- ACTIONS

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

  Widget _buildCancelButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).pop(false),
        icon: const Icon(
          Icons.close_rounded,
          size: 18,
          color: _textSecondary,
        ),
        label: const Text(
          'Cancel',
          style: TextStyle(color: _textSecondary),
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
          color: _textSecondary,
        ),
        label: const Text(
          'Use different account',
          style: TextStyle(color: _textSecondary),
        ),
      ),
    );
  }
}
