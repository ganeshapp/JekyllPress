/// Known GitHub token prefixes: classic PAT, fine-grained PAT, OAuth App
/// token, GitHub App user token.
const gitHubTokenPrefixes = ['ghp_', 'github_pat_', 'gho_', 'ghu_'];

/// True when [token] plausibly is a GitHub token: a known prefix or at
/// least 40 characters (older classic PATs are unprefixed 40-char hex).
///
/// This is a heads-up check only - callers should warn on false but still
/// allow submitting, since GitHub may introduce new formats.
bool looksLikeGitHubToken(String token) {
  final trimmed = token.trim();
  if (gitHubTokenPrefixes.any(trimmed.startsWith)) return true;
  return trimmed.length >= 40;
}
