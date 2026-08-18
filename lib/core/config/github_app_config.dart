/// Sign-in credentials bundled with the app.
///
/// A device-flow client id is public by design - no client secret is ever
/// involved - so shipping it in the binary is safe and is what lets sign-in be
/// "tap, approve, done" instead of asking every user to register their own
/// GitHub App. Override at build time with:
///
///   flutter build apk --dart-define=GITHUB_CLIENT_ID=Ov23li...
class GitHubAppConfig {
  const GitHubAppConfig._();

  /// Client id of the JekyllPress OAuth App. Empty falls back to the
  /// per-user setup card, which is also the escape hatch for anyone who
  /// prefers their own GitHub App.
  static const bundledClientId = String.fromEnvironment(
    'GITHUB_CLIENT_ID',
    defaultValue: _defaultClientId,
  );

  static const _defaultClientId = '';

  /// OAuth Apps must request a scope up front; `repo` is the narrowest one
  /// that can read and write files in a private or public repository.
  /// Left empty for GitHub Apps, whose permissions come from the
  /// registration rather than the token request.
  static const scope = 'repo';

  /// True when the app ships with credentials, so the user is never asked
  /// for a client id.
  static bool get hasBundledClientId => bundledClientId.isNotEmpty;
}
