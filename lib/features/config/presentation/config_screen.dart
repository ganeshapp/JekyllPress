import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/app_config.dart';
import '../../../core/models/github_repo.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/config_provider.dart';
import '../../../core/repositories/repo_repository.dart';
import '../../../core/services/content_service.dart';
import '../../../core/services/secure_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/desktop_content_width.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/external_url.dart';
import 'folder_browser_screen.dart';

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
      _showSnack(context.l10n.enterRepoAsOwnerName);
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
        SnackBar(
          // The background is overridden, so the foreground must come from
          // the matching `on` role - the theme's default content colour is
          // onSurface, which is unreadable on `primary` in light mode
          content: Text(
            context.l10n.selectRepositoryFirstSnack,
            style: TextStyle(color: context.colorScheme.onPrimary),
          ),
          backgroundColor: context.colorScheme.primary,
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
      _showSnack(context.l10n.rootCannotBeContentFolder);
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
        title: Text(context.l10n.changeRepositoryDialogTitle),
        content: Text(context.l10n.changeRepositoryDialogBody),
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
            child: Text(context.l10n.changeAction),
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
      _showSnack(context.l10n.pleaseSelectRepository);
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
        _showSnack(context.l10n.failedToSaveConfig('$e'));
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
        decoration: AppTheme.backgroundGradient(context),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: DesktopContentWidth(
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
                              _buildSectionTitle(
                                  context.l10n.sectionRepository),
                              _buildRepoSection(reposAsync),
                              const SizedBox(height: 28),
                              _buildSectionTitle(context.l10n.sectionBranch),
                              _buildBranchSection(),
                              const SizedBox(height: 28),
                              _buildSectionTitle(context.l10n.sectionContent),
                              _buildContentSection(),
                              const SizedBox(height: 28),
                              _buildSectionTitle(context.l10n.sectionSite),
                              _buildSiteSection(),
                              const SizedBox(height: 28),
                              _buildSectionTitle(
                                  context.l10n.sectionFrontMatterDefaults),
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
            color: context.colorScheme.outline.withAlpha(60),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.colorScheme.primary.withAlpha(30),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.settings_rounded,
            size: 32,
            color: context.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.l10n.configTitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.configTagline,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (username != null) ...[
          const SizedBox(height: 4),
          Text(
            context.l10n.loggedInAs(username),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.primary,
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
          color: context.colorScheme.primary.withAlpha(200),
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
              child: Icon(icon, color: context.colorScheme.primary, size: 22),
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
      filled: true,
      fillColor: context.colorScheme.surfaceContainer,
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
          decoration: AppTheme.cardGlow(context),
          child: reposAsync.when(
            loading: () => _buildRepoLoading(),
            error: (error, stack) => _buildRepoError(error),
            data: (repos) => _buildRepoDropdown(repos),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.chooseRepoHelper,
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
              foregroundColor: context.colorScheme.onSurfaceVariant,
            ),
            child: Text(
              _manualRepoMode
                  ? context.l10n.hideManualEntry
                  : context.l10n.manualEntryPrompt,
              style: TextStyle(
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: context.colorScheme.onSurfaceVariant,
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
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colorScheme.outline.withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colorScheme.primary,
            ),
          ),
          SizedBox(width: 16),
          Text(
            context.l10n.loadingRepositories,
            style: TextStyle(
              color: context.colorScheme.onSurfaceVariant,
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
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.colorScheme.error.withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: context.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.failedToLoadRepos('$error'),
              style: TextStyle(
                color: context.colorScheme.error,
                fontSize: 14,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: context.colorScheme.primary,
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
        hintText: context.l10n.selectBlogRepositoryHint,
      ),
      dropdownColor: context.colorScheme.surfaceContainerHigh,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: context.colorScheme.onSurfaceVariant,
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
                  style: TextStyle(
                    color: context.colorScheme.onSurface,
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
                    color: context.colorScheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.privateBadge,
                    style: TextStyle(
                      color: context.colorScheme.primary,
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
          return context.l10n.pleaseSelectRepository;
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
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorScheme.outline.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_special_rounded, color: context.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.usingRepo(repo.fullName),
              style: TextStyle(
                color: context.colorScheme.onSurface,
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
            context.colorScheme.onSurfaceVariant,
            Icons.hourglass_top_rounded,
            context.l10n.checkingForJekyllSite,
          )
        : switch (_jekyllCheck!) {
            JekyllRepoCheck.jekyll => (
                context.appColors.success,
                Icons.check_circle_rounded,
                context.l10n.jekyllSiteDetected,
              ),
            JekyllRepoCheck.couldNotVerify => (
                context.colorScheme.primary,
                Icons.help_outline_rounded,
                context.l10n.jekyllCouldNotVerify,
              ),
            JekyllRepoCheck.notJekyll => (
                context.colorScheme.error,
                Icons.warning_amber_rounded,
                context.l10n.notJekyllRepo(_jekyllCheckedPostsPath),
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
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.colorScheme.onSurfaceVariant,
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

  /// Shown when GitHub returned zero repositories. The bundled OAuth App
  /// sees every repository the `repo` scope covers, so this normally means
  /// the account really has none - but a session started with a user's own
  /// GitHub App only sees repositories it was INSTALLED on, hence the
  /// installations link.
  Widget _buildEmptyReposHint() {
    final isDeviceAuth =
        ref.watch(authMethodProvider).valueOrNull == AuthMethods.device;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colorScheme.primary.withAlpha(50),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: context.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isDeviceAuth
                      ? context.l10n.noReposFoundDeviceAuth
                      : context.l10n.noReposFoundForAccount,
                  style: TextStyle(
                    color: context.colorScheme.primary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                color: context.colorScheme.primary,
                onPressed: () => ref.invalidate(userReposProvider),
              ),
            ],
          ),
          if (isDeviceAuth) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => openExternalUrl(
                  context,
                  'https://github.com/settings/installations',
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(context.l10n.openGitHubAppInstallations),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colorScheme.primary,
                  side: BorderSide(color: context.colorScheme.primary),
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
          color: context.colorScheme.surfaceContainer.withAlpha(120),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: context.colorScheme.outline.withAlpha(50),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.fork_right_rounded,
              color: context.colorScheme.onSurfaceVariant,
              size: 22,
            ),
            SizedBox(width: 12),
            Text(
              context.l10n.selectARepositoryFirst,
              style: TextStyle(
                color: context.colorScheme.onSurfaceVariant,
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
          decoration: AppTheme.cardGlow(context),
          child: branchesAsync.when(
            loading: () => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              decoration: BoxDecoration(
                color: context.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.colorScheme.outline.withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colorScheme.primary,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    context.l10n.loadingBranches,
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
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
                color: context.colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.colorScheme.error.withAlpha(80),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: context.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.failedToLoadBranches(
                          _selectedBranch ?? repo.defaultBranch),
                      style: TextStyle(
                        color: context.colorScheme.error,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    color: context.colorScheme.primary,
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
          context.l10n.branchHelper,
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
      dropdownColor: context.colorScheme.surfaceContainerHigh,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: context.colorScheme.onSurfaceVariant,
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
                  style: TextStyle(
                    color: context.colorScheme.onSurface,
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
                    color: context.colorScheme.primary.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.defaultBranchBadge,
                    style: TextStyle(
                      color: context.colorScheme.primary,
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
          label: context.l10n.postsFolderLabel,
          controller: _postsPathController,
          icon: Icons.article_rounded,
          hint: '_posts',
          helper: context.l10n.postsFolderHelper,
          onBrowse: () => _browsePathInto(
            _postsPathController,
            '_posts',
            recheckJekyll: true,
          ),
          onSubmitted: (_) => _runJekyllCheck(),
        ),
        const SizedBox(height: 20),
        _buildPathField(
          label: context.l10n.draftsFolderLabel,
          controller: _draftsPathController,
          icon: Icons.edit_note_rounded,
          hint: '_drafts',
          helper: context.l10n.draftsFolderHelper,
          onBrowse: () => _browsePathInto(_draftsPathController, '_drafts'),
        ),
        const SizedBox(height: 20),
        _buildContentDirsEditor(),
        const SizedBox(height: 20),
        _buildPathField(
          label: context.l10n.imageAssetsPathLabel,
          controller: _assetsPathController,
          icon: Icons.image_rounded,
          hint: 'assets/images',
          helper: context.l10n.imageAssetsPathHelper,
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
                decoration: AppTheme.cardGlow(context),
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
                      return context.l10n
                          .pathFieldRequired(label.toLowerCase());
                    }
                    if (_cleanPath(value).isEmpty) {
                      return context.l10n.invalidPath;
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
            color: context.colorScheme.primary.withAlpha(20),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: context.colorScheme.surfaceContainerHigh,
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
                color: context.colorScheme.primary.withAlpha(60),
              ),
            ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colorScheme.primary,
                      ),
                    ),
                  )
                : Icon(icon, color: context.colorScheme.primary, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildContentDirsEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(context.l10n.additionalContentFoldersLabel),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final dir in _extraContentDirs)
              InputChip(
                label: Text(dir),
                labelStyle: TextStyle(
                  color: context.colorScheme.onSurface,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                backgroundColor: context.colorScheme.surfaceContainer,
                deleteIconColor: context.colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: context.colorScheme.outline.withAlpha(80)),
                ),
                onDeleted: () {
                  setState(() => _extraContentDirs.remove(dir));
                },
              ),
            ActionChip(
              avatar: Icon(
                Icons.add_rounded,
                size: 18,
                color: context.colorScheme.primary,
              ),
              label: Text(context.l10n.addFolder),
              labelStyle: TextStyle(
                color: context.colorScheme.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: context.colorScheme.primary.withAlpha(15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: context.colorScheme.primary.withAlpha(60)),
              ),
              onPressed: _addContentDir,
            ),
          ],
        ),
        _buildHelperText(context.l10n.additionalContentFoldersHelper),
      ],
    );
  }

  // ---------------------------------------------------------------- SITE

  Widget _buildSiteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(context.l10n.siteUrlLabel),
        Container(
          decoration: AppTheme.cardGlow(context),
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
        _buildHelperText(context.l10n.siteUrlHelper),
        const SizedBox(height: 20),
        _buildFieldLabel(context.l10n.baseUrlLabel),
        Container(
          decoration: AppTheme.cardGlow(context),
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
        _buildHelperText(context.l10n.baseUrlHelper),
      ],
    );
  }

  // -------------------------------------------------------- FRONT MATTER

  Widget _buildFrontMatterSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.frontMatterHelper,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
              ),
        ),
        const SizedBox(height: 16),
        _buildFieldLabel(context.l10n.layoutLabel),
        Container(
          decoration: AppTheme.cardGlow(context),
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
        _buildFieldLabel(context.l10n.defaultCategoriesLabel),
        Container(
          decoration: AppTheme.cardGlow(context),
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
              hintText: context.l10n.defaultCategoriesHint,
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildFieldLabel(context.l10n.defaultTagsLabel),
        Container(
          decoration: AppTheme.cardGlow(context),
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
              hintText: context.l10n.defaultTagsHint,
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
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: context.colorScheme.onPrimary,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(context.l10n.saveConfiguration),
                ],
              ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).pop(false),
        icon: Icon(
          Icons.close_rounded,
          size: 18,
          color: context.colorScheme.onSurfaceVariant,
        ),
        label: Text(
          context.l10n.commonCancel,
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
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
        icon: Icon(
          Icons.logout_rounded,
          size: 18,
          color: context.colorScheme.onSurfaceVariant,
        ),
        label: Text(
          context.l10n.useDifferentAccount,
          style: TextStyle(color: context.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
