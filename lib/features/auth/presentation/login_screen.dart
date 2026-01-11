import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _tokenController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureToken = true;
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
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _animController.dispose();
    super.dispose();
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),
                      _buildHeader(),
                      const SizedBox(height: 48),
                      _buildTokenField(isLoading),
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorMessage(errorMessage),
                      ],
                      const SizedBox(height: 32),
                      _buildLoginButton(isLoading),
                      const SizedBox(height: 24),
                      _buildHelpText(),
                      const Spacer(flex: 3),
                    ],
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
          if (!value.startsWith('ghp_') && 
              !value.startsWith('github_pat_') &&
              value.length < 20) {
            return 'This doesn\'t look like a valid token';
          }
          return null;
        },
        onFieldSubmitted: (_) => _validateAndLogin(),
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
      child: ElevatedButton(
        onPressed: isLoading ? null : _validateAndLogin,
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
                  Text('Connect to GitHub'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }

  Widget _buildHelpText() {
    return Column(
      children: [
        Text(
          'Need a token?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () {
            // TODO: Open GitHub token creation page
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Visit GitHub → Settings → Developer Settings → Personal Access Tokens'),
              ),
            );
          },
          child: const Text('Create one on GitHub →'),
        ),
      ],
    );
  }
}
