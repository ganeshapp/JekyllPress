import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/models/github_repo.dart';
import 'package:jekyllpress/core/repositories/repo_repository.dart';

import 'fakes.dart';

String _reposJson(int count, {int startId = 0}) {
  return jsonEncode(List.generate(count, (i) {
    final id = startId + i;
    return {
      'id': id,
      'name': 'repo$id',
      'full_name': 'gapp/repo$id',
      'owner': {'login': 'gapp'},
      'private': false,
      'default_branch': 'main',
      'html_url': 'https://github.com/gapp/repo$id',
    };
  }));
}

GitHubRepo _repo() => GitHubRepo.fromJson({
      'id': 1,
      'name': 'blog',
      'full_name': 'gapp/blog',
      'owner': {'login': 'gapp'},
      'private': false,
      'default_branch': 'main',
      'html_url': 'https://github.com/gapp/blog',
    });

void main() {
  group('RepoRepository.getUserRepos', () {
    test('requests owner+collaborator+org repos sorted by pushed, '
        '30 per page, without the type filter', () async {
      final requests = <RequestOptions>[];
      final dio = dioWithResponse((options) {
        requests.add(options);
        return jsonResponse(_reposJson(5), 200);
      });

      final repos = await RepoRepository(dio: dio).getUserRepos();

      expect(repos, hasLength(5));
      final query = requests.single.queryParameters;
      expect(query['affiliation'], 'owner,collaborator,organization_member');
      expect(query['sort'], 'pushed');
      expect(query['per_page'], 30);
      expect(query.containsKey('type'), isFalse);
    });

    test('fetches at most 3 pages of 30', () async {
      final pagesRequested = <int>[];
      final dio = dioWithResponse((options) {
        final page = options.queryParameters['page'] as int;
        pagesRequested.add(page);
        // Always full pages - without the cap this would loop forever
        return jsonResponse(_reposJson(30, startId: page * 100), 200);
      });

      final repos = await RepoRepository(dio: dio).getUserRepos();

      expect(pagesRequested, [1, 2, 3]);
      expect(repos, hasLength(90));
    });

    test('stops early on a short page', () async {
      final pagesRequested = <int>[];
      final dio = dioWithResponse((options) {
        final page = options.queryParameters['page'] as int;
        pagesRequested.add(page);
        return jsonResponse(
            page == 1 ? _reposJson(30) : _reposJson(3, startId: 100), 200);
      });

      final repos = await RepoRepository(dio: dio).getUserRepos();

      expect(pagesRequested, [1, 2]);
      expect(repos, hasLength(33));
    });
  });

  group('RepoRepository.getRepo', () {
    test('fetches a single repository by owner/name', () async {
      final requests = <RequestOptions>[];
      final dio = dioWithResponse((options) {
        requests.add(options);
        return jsonResponse(jsonEncode({
          'id': 42,
          'name': 'wiki',
          'full_name': 'some-org/wiki',
          'owner': {'login': 'some-org'},
          'private': true,
          'default_branch': 'trunk',
          'html_url': 'https://github.com/some-org/wiki',
        }), 200);
      });

      final repo = await RepoRepository(dio: dio)
          .getRepo(repoOwner: 'some-org', repoName: 'wiki');

      expect(requests.single.path, '/repos/some-org/wiki');
      expect(repo.ownerLogin, 'some-org');
      expect(repo.name, 'wiki');
      expect(repo.defaultBranch, 'trunk');
      expect(repo.isPrivate, isTrue);
    });

    test('404 surfaces a clear not-found message', () async {
      final dio = dioWithResponse(
          (options) => jsonResponse('{"message":"Not Found"}', 404));

      expect(
        () => RepoRepository(dio: dio)
            .getRepo(repoOwner: 'gapp', repoName: 'nope'),
        throwsA(predicate((e) =>
            e.toString().contains('gapp/nope') &&
            e.toString().contains('not found'))),
      );
    });
  });

  group('RepoRepository.getBranches', () {
    test('requests 100 branches per page and returns their names', () async {
      final requests = <RequestOptions>[];
      final dio = dioWithResponse((options) {
        requests.add(options);
        return jsonResponse(
            jsonEncode([
              {'name': 'main', 'protected': true},
              {'name': 'gh-pages', 'protected': false},
              {'name': 'drafts', 'protected': false},
            ]),
            200);
      });

      final branches = await RepoRepository(dio: dio)
          .getBranches(repoOwner: 'gapp', repoName: 'blog');

      expect(requests.single.path, '/repos/gapp/blog/branches');
      expect(requests.single.queryParameters['per_page'], 100);
      expect(branches, ['main', 'gh-pages', 'drafts']);
    });

    test('errors surface as a clean user-facing message', () async {
      final dio = dioWithError((options) => DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ));

      expect(
        () => RepoRepository(dio: dio)
            .getBranches(repoOwner: 'gapp', repoName: 'blog'),
        throwsA(predicate(
            (e) => e.toString().contains('No internet connection'))),
      );
    });
  });

  group('RepoRepository.isJekyllRepo', () {
    test('_config.yml on the branch means jekyll', () async {
      final requests = <RequestOptions>[];
      final dio = dioWithResponse((options) {
        requests.add(options);
        if (options.path.endsWith('_config.yml')) {
          return jsonResponse('{"name":"_config.yml"}', 200);
        }
        return jsonResponse('{"message":"Not Found"}', 404);
      });

      final result = await RepoRepository(dio: dio).isJekyllRepo(_repo());

      expect(result, JekyllRepoCheck.jekyll);
      // The selected branch defaults to the repo's default branch
      expect(requests.first.queryParameters['ref'], 'main');
    });

    test('no _config.yml but a posts dir means jekyll, on the '
        'selected branch and configured postsPath', () async {
      final requests = <RequestOptions>[];
      final dio = dioWithResponse((options) {
        requests.add(options);
        if (options.path.endsWith('docs/_posts')) {
          return jsonResponse('[]', 200);
        }
        return jsonResponse('{"message":"Not Found"}', 404);
      });

      final result = await RepoRepository(dio: dio).isJekyllRepo(
        _repo(),
        postsPath: 'docs/_posts',
        branch: 'gh-pages',
      );

      expect(result, JekyllRepoCheck.jekyll);
      for (final r in requests) {
        expect(r.queryParameters['ref'], 'gh-pages');
      }
    });

    test('clean 404s on both probes means definitely not jekyll', () async {
      final dio = dioWithResponse(
          (options) => jsonResponse('{"message":"Not Found"}', 404));

      final result = await RepoRepository(dio: dio).isJekyllRepo(_repo());

      expect(result, JekyllRepoCheck.notJekyll);
    });

    test('403 is could-not-verify, never "not jekyll"', () async {
      final dio = dioWithResponse((options) {
        if (options.path.endsWith('_config.yml')) {
          return jsonResponse('{"message":"Forbidden"}', 403);
        }
        return jsonResponse('{"message":"Not Found"}', 404);
      });

      final result = await RepoRepository(dio: dio).isJekyllRepo(_repo());

      expect(result, JekyllRepoCheck.couldNotVerify);
    });

    test('network failure is could-not-verify', () async {
      final dio = dioWithError((options) => DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          ));

      final result = await RepoRepository(dio: dio).isJekyllRepo(_repo());

      expect(result, JekyllRepoCheck.couldNotVerify);
    });
  });
}
