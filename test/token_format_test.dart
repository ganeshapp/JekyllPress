import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/utils/token_format.dart';

void main() {
  group('looksLikeGitHubToken', () {
    test('accepts every known GitHub token prefix regardless of length',
        () {
      expect(looksLikeGitHubToken('ghp_short'), isTrue);
      expect(looksLikeGitHubToken('github_pat_short'), isTrue);
      expect(looksLikeGitHubToken('gho_short'), isTrue);
      expect(looksLikeGitHubToken('ghu_short'), isTrue);
    });

    test('accepts unprefixed tokens of 40+ chars (legacy hex PATs)', () {
      expect(looksLikeGitHubToken('a' * 40), isTrue);
      expect(looksLikeGitHubToken('a' * 64), isTrue);
    });

    test('warns on short unprefixed strings', () {
      expect(looksLikeGitHubToken('a' * 39), isFalse);
      expect(looksLikeGitHubToken('not-a-token'), isFalse);
      expect(looksLikeGitHubToken('ghs_server_token'), isFalse);
    });

    test('trims surrounding whitespace before checking', () {
      expect(looksLikeGitHubToken('  ghp_token  '), isTrue);
      expect(looksLikeGitHubToken('  ${'a' * 40}  '), isTrue);
    });
  });
}
