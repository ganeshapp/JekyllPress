import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/dio_client.dart';
import '../../../core/services/github_oauth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/token_format.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  /// Compile-time default GitHub App / OAuth App client id
  /// (--dart-define=GITHUB_CLIENT_ID=Iv1.xxx). Empty when not provided.
  static const _envClientId = String.fromEnvironment('GITHUB_CLIENT_ID');

  static const _appSetupUrl = 'https://github.com/settings/apps/new';
  static const _createTokenUrl =
      'https://github.com/settings/tokens/new?scopes=repo&description=JekyllPress';

  final _tokenController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureToken = true;
  bool _showSetupCard = false;
  bool _showPatSection = false;
  bool _showFormatWarning = false;
  String? _storedClientId;
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _animController.forward();

    // A client id saved during a previous session makes re-login one tap
    ref.read(secureStorageProvider).getClientId().then((value) {
      if (mounted) setState(() => _storedClientId = value);
    });
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _clientIdController.dispose();
    _animController.dispose();
    super.dispose();
  }

  /// Client id for device-flow sign-in: compile-time default first, then
  /// the one the user saved. Null when neither exists yet.
  String? get _clientId {
    if (_envClientId.isNotEmpty) return _envClientId;
    final stored = _storedClientId;
    if (stored != null && stored.isNotEmpty) return stored;
    return null;
  }

  Future<void> _openUrl(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open browser - link copied: $url')),
      );
    }
  }

  Future<void> _onSignInWithGitHub() async {
    final clientId = _clientId;
    if (clientId == null) {
      // First run without a compile-time id: one-time setup
      setState(() => _showSetupCard = true);
      return;
    }
    await _startDeviceFlow(clientId);
  }

  Future<void> _saveClientIdAndSignIn() async {
    final clientId = _clientIdController.text.trim();
    if (clientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste the Client ID from your GitHub App')),
      );
      return;
    }
    await ref.read(secureStorageProvider).saveClientId(clientId);
    if (!mounted) return;
    setState(() {
      _storedClientId = clientId;
      _showSetupCard = false;
    });
    await _startDeviceFlow(clientId);
  }

  Future<void> _startDeviceFlow(String clientId) async {
    final tokens = await showModalBottomSheet<OAuthTokens>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF1A2F23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _DeviceFlowSheet(clientId: clientId),
    );
    if (tokens == null || !mounted) return;

    final success = await ref
        .read(authNotifierProvider.notifier)
        .completeDeviceLogin(tokens: tokens, clientId: clientId);
    if (success && mounted) {
      // Navigation will be handled by the app's auth state listener
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _validateAndLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref
        .read(authNotifierProvider.notifier)
        .login(_tokenController.text);

    if (success && mounted) {
      // Navigation will be handled by the app's auth state listener
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState is AuthLoading;
    final errorMessage = authState is AuthUnauthenticated ? authState.message : null;

    return Scaffold(
      body: Container(
        decoration: AppTheme.backgroundGradient,
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 32,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 48),
                        if (_showSetupCard) ...[
                          _buildSetupCard(isLoading),
                          const SizedBox(height: 24),
                        ],
                        _buildDeviceSignInButton(isLoading),
                        if (errorMessage != null) ...[
                          const SizedBox(height: 16),
                          _buildErrorMessage(errorMessage),
                        ],
                        const SizedBox(height: 20),
                        _buildPatToggle(isLoading),
                        if (_showPatSection) ...[
                          const SizedBox(height: 16),
                          _buildTokenField(isLoading),
                          if (_showFormatWarning) ...[
                            const SizedBox(height: 12),
                            _buildFormatWarning(),
                          ],
                          const SizedBox(height: 20),
                          _buildLoginButton(isLoading),
                          const SizedBox(height: 8),
                          _buildCreateTokenButton(isLoading),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2D4A3E).withAlpha(60),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE8A87C).withAlpha(30),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.edit_note_rounded,
            size: 40,
            color: Color(0xFFE8A87C),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'JekyllPress',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your mobile CMS for Jekyll blogs.\nConnect with your GitHub account.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
              ),
        ),
      ],
    );
  }

  Widget _buildDeviceSignInButton(bool isLoading) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _onSignInWithGitHub,
        child: isLoading
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
                  Icon(Icons.verified_user_rounded, size: 20),
                  SizedBox(width: 10),
                  Text('Sign in with GitHub'),
                ],
              ),
      ),
    );
  }

  /// One-time card shown when no client id exists yet (neither compiled
  /// in nor previously saved). Once an id is saved it never reappears.
  Widget _buildSetupCard(bool isLoading) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2F23),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE8A87C).withAlpha(60),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.rocket_launch_rounded,
                size: 20,
                color: Color(0xFFE8A87C),
              ),
              const SizedBox(width: 10),
              Text(
                'One-time setup',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Signing in without a token requires a free GitHub App you '
            'register once on your account. Give it the Contents: Read & '
            'write permission and enable Device Flow, then paste its '
            'Client ID here - JekyllPress remembers it forever.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: isLoading ? null : () => _openUrl(_appSetupUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open GitHub App setup'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE8A87C),
              side: const BorderSide(color: Color(0xFFE8A87C)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _clientIdController,
            enabled: !isLoading,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              fontSize: 15,
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
            decoration: const InputDecoration(
              labelText: 'Client ID',
              hintText: 'Iv23xxxxxxxxxxxxxxxx',
            ),
            onSubmitted: (_) => _saveClientIdAndSignIn(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: isLoading ? null : _saveClientIdAndSignIn,
              child: const Text('Save & sign in'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatToggle(bool isLoading) {
    return TextButton.icon(
      onPressed: isLoading
          ? null
          : () => setState(() => _showPatSection = !_showPatSection),
      icon: Icon(
        _showPatSection
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
        size: 20,
        color: const Color(0xFFA8B5A0),
      ),
      label: const Text(
        'Use a Personal Access Token instead',
        style: TextStyle(color: Color(0xFFA8B5A0)),
      ),
    );
  }

  Widget _buildTokenField(bool isLoading) {
    return Container(
      decoration: AppTheme.cardGlow,
      child: TextFormField(
        controller: _tokenController,
        enabled: !isLoading,
        obscureText: _obscureToken,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(
          fontSize: 15,
          fontFamily: 'monospace',
          letterSpacing: 1,
        ),
        decoration: InputDecoration(
          labelText: 'Personal Access Token',
          hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.key_rounded,
              color: Color(0xFFE8A87C),
              size: 22,
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureToken ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: const Color(0xFFA8B5A0),
              size: 22,
            ),
            onPressed: () => setState(() => _obscureToken = !_obscureToken),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter your GitHub token';
          }
          // Format oddities only warn (below the field); GitHub may add
          // new token formats and the API is the real judge
          return null;
        },
        onChanged: (value) {
          final warn =
              value.trim().isNotEmpty && !looksLikeGitHubToken(value);
          if (warn != _showFormatWarning) {
            setState(() => _showFormatWarning = warn);
          }
        },
        onFieldSubmitted: (_) => _validateAndLogin(),
      ),
    );
  }

  Widget _buildFormatWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8A87C).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE8A87C).withAlpha(50),
          width: 1,
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFE8A87C),
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This doesn\'t look like a GitHub token - double-check it. '
              'You can still try connecting.',
              style: TextStyle(
                color: Color(0xFFE8A87C),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE57373).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE57373).withAlpha(50),
          width: 1,
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
              message,
              style: const TextStyle(
                color: Color(0xFFE57373),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(bool isLoading) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading ? null : _validateAndLogin,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE8A87C),
          side: const BorderSide(color: Color(0xFFE8A87C)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFFE8A87C),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Connect with token'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildCreateTokenButton(bool isLoading) {
    return TextButton.icon(
      onPressed: isLoading ? null : () => _openUrl(_createTokenUrl),
      icon: const Icon(Icons.open_in_new_rounded, size: 16),
      label: const Text('Create a token on GitHub'),
    );
  }
}

/// Bottom sheet driving the GitHub Device Flow: shows the user code
/// (auto-copied), opens github.com/login/device, and polls until the user
/// authorizes, cancels, or the code expires. Pops with the [OAuthTokens]
/// on success, null otherwise.
class _DeviceFlowSheet extends ConsumerStatefulWidget {
  final String clientId;

  const _DeviceFlowSheet({required this.clientId});

  @override
  ConsumerState<_DeviceFlowSheet> createState() => _DeviceFlowSheetState();
}

class _DeviceFlowSheetState extends ConsumerState<_DeviceFlowSheet> {
  DeviceCodeResponse? _code;
  String? _error;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    // The sheet can be dismissed without the Cancel button (system back
    // pops it even with isDismissible: false) - always stop the polling
    // loop when the sheet goes away
    _cancelled = true;
    super.dispose();
  }

  Future<void> _run() async {
    final oauthService = ref.read(gitHubOAuthServiceProvider);
    try {
      final code = await oauthService.startDeviceFlow(widget.clientId);
      if (!mounted || _cancelled) return;
      setState(() => _code = code);
      // Save the user a copy step: the code is on the clipboard already
      await Clipboard.setData(ClipboardData(text: code.userCode));

      final result = await oauthService.pollForToken(
        clientId: widget.clientId,
        deviceCode: code.deviceCode,
        interval: code.interval,
        expiresIn: code.expiresIn,
        isCancelled: () => _cancelled,
      );
      if (!mounted) return;

      switch (result) {
        case DeviceFlowSuccess(tokens: final tokens):
          Navigator.of(context).pop(tokens);
        case DeviceFlowCancelled():
          break; // The cancel button already closed the sheet
        case DeviceFlowExpired(message: final message):
        case DeviceFlowDenied(message: final message):
        case DeviceFlowDisabled(message: final message):
        case DeviceFlowFailure(message: final message):
          setState(() => _error = message);
      }
    } on ApiException catch (e) {
      if (mounted && !_cancelled) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && !_cancelled) {
        setState(() => _error = 'GitHub sign-in failed - try again');
      }
    }
  }

  void _cancel() {
    _cancelled = true;
    Navigator.of(context).pop();
  }

  Future<void> _openVerificationPage() async {
    final url = _code?.verificationUri ?? 'https://github.com/login/device';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // The code is on the clipboard; the user can browse there manually
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Sign in with GitHub',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: _cancel,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFA8B5A0),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null)
              _buildError(_error!)
            else if (_code == null)
              _buildRequesting()
            else
              _buildWaiting(_code!),
          ],
        ),
      ),
    );
  }

  Widget _buildRequesting() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
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
            'Requesting a code from GitHub...',
            style: TextStyle(color: Color(0xFFA8B5A0), fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting(DeviceCodeResponse code) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Enter this code on GitHub:',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE8A87C).withAlpha(60),
              width: 1,
            ),
          ),
          child: Text(
            code.userCode,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 4,
              color: Color(0xFFE8D5B5),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Copied to clipboard',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF81C784), fontSize: 12),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _openVerificationPage,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Open github.com/login/device'),
          ),
        ),
        const SizedBox(height: 20),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFE8A87C),
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Waiting for you to authorize...',
              style: TextStyle(color: Color(0xFFA8B5A0), fontSize: 14),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cancel,
          child: const Text(
            'Cancel',
            style: TextStyle(color: Color(0xFFA8B5A0)),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE57373).withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE57373).withAlpha(50),
              width: 1,
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
                  message,
                  style: const TextStyle(
                    color: Color(0xFFE57373),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _cancel,
            child: const Text('Close'),
          ),
        ),
      ],
    );
  }
}
