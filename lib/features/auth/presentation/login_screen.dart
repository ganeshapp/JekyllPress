import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/github_app_config.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/dio_client.dart';
import '../../../core/services/github_oauth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/token_format.dart';
import '../../../l10n/l10n.dart';
import '../../../core/utils/external_url.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  /// Client id bundled with the app (see [GitHubAppConfig]). When set, the
  /// user never sees the setup card at all.
  static const _envClientId = GitHubAppConfig.bundledClientId;

  /// GitHub's new-app form, pre-filled via its documented URL parameters so
  /// the user only has to tick "Enable Device Flow" (the one setting GitHub
  /// exposes no parameter for) and press Create. Without this the form asks
  /// for a webhook URL, redirect URIs, and permissions that JekyllPress does
  /// not use.
  static const _appSetupUrl =
      'https://github.com/settings/apps/new'
      '?name=JekyllPress'
      '&description=Write%20and%20publish%20posts%20to%20my%20Jekyll%20blog%20from%20my%20phone'
      '&url=https%3A%2F%2Fgithub.com%2Fganeshapp%2FJekyllPress'
      '&public=false'
      '&webhook_active=false'
      '&contents=write';
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

  Future<void> _openUrl(String url) => openExternalUrl(context, url);

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
        SnackBar(content: Text(context.l10n.pasteClientIdPrompt)),
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
    final result = await showModalBottomSheet<_DeviceFlowResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => _DeviceFlowSheet(clientId: clientId),
    );
    if (result == null || !mounted) return;

    // A rejected client id (e.g. Device Flow not enabled on the app) would
    // otherwise dead-end here: the stored id keeps failing and the setup card
    // is unreachable. Reopen it with the current id ready to edit.
    if (result is _DeviceFlowChangeClientId) {
      _clientIdController.text = clientId;
      setState(() => _showSetupCard = true);
      return;
    }

    final tokens = (result as _DeviceFlowSuccess).tokens;
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
        decoration: AppTheme.backgroundGradient(context),
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
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.outline.withAlpha(60),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.primary.withAlpha(30),
              width: 1,
            ),
          ),
          child: Icon(
            Icons.edit_note_rounded,
            size: 40,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.appTitle,
          style: context.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.loginTagline,
          style: context.textTheme.bodyMedium?.copyWith(
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
                  const Icon(Icons.verified_user_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(context.l10n.signInWithGitHub),
                ],
              ),
      ),
    );
  }

  /// One-time card shown when no client id exists yet (neither compiled
  /// in nor previously saved). Once an id is saved it never reappears.
  Widget _buildSetupCard(bool isLoading) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.primary.withAlpha(60),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.rocket_launch_rounded,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Text(
                context.l10n.oneTimeSetupTitle,
                style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.oneTimeSetupBody,
            style: context.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.appNameTakenHint,
            style: context.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: isLoading ? null : () => _openUrl(_appSetupUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(context.l10n.openGitHubAppSetup),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.oneTimeSetupInstallHint,
            style: context.textTheme.bodySmall,
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
            decoration: InputDecoration(
              labelText: context.l10n.clientIdLabel,
              hintText: 'Iv23xxxxxxxxxxxxxxxx',
            ),
            onSubmitted: (_) => _saveClientIdAndSignIn(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isLoading ? null : _saveClientIdAndSignIn,
            // minimumSize rather than a fixed-height SizedBox: keeps the 48dp
            // tap target but lets the button grow so the label is never
            // clipped at larger system font scales.
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(context.l10n.saveAndSignIn),
          ),
        ],
      ),
    );
  }

  Widget _buildPatToggle(bool isLoading) {
    final scheme = context.colorScheme;
    return TextButton.icon(
      onPressed: isLoading
          ? null
          : () => setState(() => _showPatSection = !_showPatSection),
      icon: Icon(
        _showPatSection
            ? Icons.keyboard_arrow_up_rounded
            : Icons.keyboard_arrow_down_rounded,
        size: 20,
        color: scheme.onSurfaceVariant,
      ),
      label: Text(
        context.l10n.usePatInstead,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildTokenField(bool isLoading) {
    final scheme = context.colorScheme;
    return Container(
      decoration: AppTheme.cardGlow(context),
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
          labelText: context.l10n.patLabel,
          hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 16, right: 12),
            child: Icon(
              Icons.key_rounded,
              color: scheme.primary,
              size: 22,
            ),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureToken ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: scheme.onSurfaceVariant,
              size: 22,
            ),
            tooltip: _obscureToken
                ? context.l10n.showTokenTooltip
                : context.l10n.hideTokenTooltip,
            onPressed: () => setState(() => _obscureToken = !_obscureToken),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return context.l10n.enterTokenValidation;
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
    final warning = context.appColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: warning.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: warning.withAlpha(50),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.tokenFormatWarning,
              style: TextStyle(
                color: warning,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    final error = context.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: error.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: error.withAlpha(50),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: error,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: error,
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
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(context.l10n.connectWithToken),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildCreateTokenButton(bool isLoading) {
    return TextButton.icon(
      onPressed: isLoading ? null : () => _openUrl(_createTokenUrl),
      icon: const Icon(Icons.open_in_new_rounded, size: 16),
      label: Text(context.l10n.createTokenOnGitHub),
    );
  }
}

/// Bottom sheet driving the GitHub Device Flow: shows the user code
/// (auto-copied), opens github.com/login/device, and polls until the user
/// authorizes, cancels, or the code expires. Pops with the [OAuthTokens]
/// on success, null otherwise.
/// Outcome of the device-flow sheet.
sealed class _DeviceFlowResult {
  const _DeviceFlowResult();
}

class _DeviceFlowSuccess extends _DeviceFlowResult {
  const _DeviceFlowSuccess(this.tokens);
  final OAuthTokens tokens;
}

/// The user wants to correct the client id rather than retry with this one.
class _DeviceFlowChangeClientId extends _DeviceFlowResult {
  const _DeviceFlowChangeClientId();
}

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
      final code = await oauthService.startDeviceFlow(
        widget.clientId,
        scope: GitHubAppConfig.scope,
      );
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
          Navigator.of(context).pop(_DeviceFlowSuccess(tokens));
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
        setState(() => _error = context.l10n.deviceSignInFailed);
      }
    }
  }

  void _cancel() {
    _cancelled = true;
    Navigator.of(context).pop();
  }

  Future<void> _openVerificationPage() async {
    final url = _code?.verificationUri ?? 'https://github.com/login/device';
    // The code is already on the clipboard, so a failure here still leaves the
    // user able to browse to the page manually.
    await openExternalUrl(context, url);
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
                    context.l10n.signInWithGitHub,
                    style: context.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: _cancel,
                  tooltip: context.l10n.cancelSignInTooltip,
                  icon: Icon(
                    Icons.close_rounded,
                    color: context.colorScheme.onSurfaceVariant,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            context.l10n.requestingCodeFromGitHub,
            style: TextStyle(
              color: context.colorScheme.onSurfaceVariant,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaiting(DeviceCodeResponse code) {
    final scheme = context.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.enterCodeOnGitHub,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.primary.withAlpha(60),
              width: 1,
            ),
          ),
          child: Text(
            code.userCode,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 4,
              color: scheme.tertiary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.copiedToClipboard,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.appColors.success, fontSize: 12),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _openVerificationPage,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(context.l10n.openGitHubDeviceLogin),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.waitingForAuthorization,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _cancel,
          child: Text(
            context.l10n.commonCancel,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    final error = context.colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: error.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: error.withAlpha(50),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: error,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: error,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _cancel,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          child: Text(context.l10n.commonClose),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () {
            _cancelled = true;
            Navigator.of(context).pop(const _DeviceFlowChangeClientId());
          },
          child: Text(context.l10n.changeClientId),
        ),
      ],
    );
  }
}
