import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/models/app_config.dart';
import 'package:jekyllpress/core/models/blog_post.dart';
import 'package:jekyllpress/core/services/content_service.dart';

import 'fakes.dart';

AppConfig _config({String branch = 'main', String? activeContentDir}) {
  return AppConfig(
    repoOwner: 'gapp',
    repoName: 'blog',
    branch: branch,
    activeContentDir: activeContentDir,
  );
}

String _treesJson({required List<Map<String, dynamic>> tree, bool truncated = false}) {
  return jsonEncode({'sha': 'root', 'tree': tree, 'truncated': truncated});
}

Map<String, dynamic> _blob(String path, String sha) =>
    {'path': path, 'type': 'blob', 'sha': sha, 'size': 100};

Map<String, dynamic> _tree(String path) =>
    {'path': path, 'type': 'tree', 'sha': 'tree_$path'};

String _contentsFileJson(String body) {
  return jsonEncode({
    'encoding': 'base64',
    'content': base64Encode(utf8.encode(body)),
  });
}

String _post(String title, String date) =>
    '---\ntitle: "$title"\ndate: $date\n---\nbody of $title';

void main() {
  group('ContentService.cleanDir', () {
    test('strips leading and trailing slashes', () {
      expect(ContentService.cleanDir('/_posts/'), '_posts');
      expect(ContentService.cleanDir('docs/_posts'), 'docs/_posts');
      expect(ContentService.cleanDir('//_wiki//'), '_wiki');
    });
  });

  group('ContentService.fetchPostsList (git trees)', () {
    test('requests the configured branch recursively and filters to '
        'markdown blobs under the active dir (incl. subfolders)', () async {
      final requests = <RequestOptions>[];
      final dio = dioWithResponse((options) {
        requests.add(options);
        return jsonResponse(
          _treesJson(tree: [
            _tree('_posts'),
            _tree('_posts/2024'),
            _blob('_posts/2024/deep.md', 's1'),
            _blob('_posts/top.markdown', 's2'),
            _blob('_posts/image.png', 's3'), // not markdown
            _blob('_wiki/other.md', 's4'), // other dir
            _blob('_postsx/trick.md', 's5'), // prefix but not the dir
            _blob('README.md', 's6'), // repo root
          ]),
          200,
        );
      });
      final service = ContentService(dio: dio);

      final files = await service.fetchPostsList(_config(branch: 'dev'));

      expect(requests, hasLength(1));
      expect(requests.first.path, '/repos/gapp/blog/git/trees/dev');
      expect(requests.first.queryParameters['recursive'], '1');
      expect(files.map((f) => f.path),
          ['_posts/2024/deep.md', '_posts/top.markdown']);
      // Name is the basename, path is the full repo-relative path
      expect(files.first.name, 'deep.md');
      expect(files.first.sha, 's1');
    });

    test('branch names with slashes are URL-encoded', () async {
      String? seenPath;
      final dio = dioWithResponse((options) {
        seenPath = options.path;
        return jsonResponse(_treesJson(tree: []), 200);
      });
      final service = ContentService(dio: dio);

      await service.fetchPostsList(_config(branch: 'feature/x'));

      expect(seenPath, '/repos/gapp/blog/git/trees/feature%2Fx');
    });

    test('uses the active content dir, not _posts', () async {
      final dio = dioWithResponse((options) {
        return jsonResponse(
          _treesJson(tree: [
            _blob('_wiki/a.md', 's1'),
            _blob('_posts/b.md', 's2'),
          ]),
          200,
        );
      });
      final service = ContentService(dio: dio);

      final files = await service
          .fetchPostsList(_config(activeContentDir: '_wiki'));

      expect(files.map((f) => f.path), ['_wiki/a.md']);
    });

    test('truncated tree falls back to per-directory contents listing '
        'with the branch ref', () async {
      final requests = <RequestOptions>[];
      final dio = dioWithResponse((options) {
        requests.add(options);
        if (options.path.contains('/git/trees/')) {
          return jsonResponse(_treesJson(tree: [], truncated: true), 200);
        }
        if (options.path == '/repos/gapp/blog/contents/_posts') {
          return jsonResponse(
            jsonEncode([
              {'name': '2024', 'path': '_posts/2024', 'sha': 'd1', 'type': 'dir'},
              {'name': 'a.md', 'path': '_posts/a.md', 'sha': 's1', 'type': 'file'},
              {'name': 'x.png', 'path': '_posts/x.png', 'sha': 's2', 'type': 'file'},
            ]),
            200,
          );
        }
        if (options.path == '/repos/gapp/blog/contents/_posts/2024') {
          return jsonResponse(
            jsonEncode([
              {'name': 'b.md', 'path': '_posts/2024/b.md', 'sha': 's3', 'type': 'file'},
            ]),
            200,
          );
        }
        return jsonResponse('{"message":"Not Found"}', 404);
      });
      final service = ContentService(dio: dio);

      final files = await service.fetchPostsList(_config(branch: 'dev'));

      expect(files.map((f) => f.path),
          containsAll(['_posts/a.md', '_posts/2024/b.md']));
      expect(files, hasLength(2));
      // Every contents read carried the branch ref
      final contentsRequests =
          requests.where((r) => r.path.contains('/contents/'));
      expect(contentsRequests, isNotEmpty);
      for (final r in contentsRequests) {
        expect(r.queryParameters['ref'], 'dev');
      }
    });

    test('404 (missing branch) and 409 (empty repo) yield empty list', () async {
      for (final status in [404, 409]) {
        final dio = dioWithResponse(
            (options) => jsonResponse('{"message":"nope"}', status));
        final service = ContentService(dio: dio);
        expect(await service.fetchPostsList(_config()), isEmpty);
      }
    });
  });

  group('ContentService.fetchFileContent', () {
    test('passes the branch ref', () async {
      RequestOptions? seen;
      final dio = dioWithResponse((options) {
        seen = options;
        return jsonResponse(_contentsFileJson('hello'), 200);
      });
      final service = ContentService(dio: dio);

      final content = await service.fetchFileContent(
          _config(branch: 'dev'), '_posts/a.md');

      expect(content, 'hello');
      expect(seen!.queryParameters['ref'], 'dev');
    });
  });

  group('ContentService.syncPosts', () {
    test('fetches only changed files, sets filePath, keeps unchanged, '
        'and reports progress', () async {
      final fetchedPaths = <String>[];
      final dio = dioWithResponse((options) {
        if (options.path.contains('/git/trees/')) {
          return jsonResponse(
            _treesJson(tree: [
              _blob('_posts/unchanged.md', 'sha_same'),
              _blob('_posts/changed.md', 'sha_new'),
              _blob('_posts/2024/added.md', 'sha_added'),
            ]),
            200,
          );
        }
        fetchedPaths.add(options.path);
        if (options.path.endsWith('changed.md')) {
          return jsonResponse(
              _contentsFileJson(_post('Changed', '2026-08-02')), 200);
        }
        return jsonResponse(
            _contentsFileJson(_post('Added', '2026-08-03')), 200);
      });
      final service = ContentService(dio: dio);

      final existing = BlogPost(
        sha: 'sha_same',
        fileName: 'unchanged.md',
        filePath: '_posts/unchanged.md',
        title: 'Unchanged',
        date: '2026-08-01',
        bodyContent: 'cached',
      );

      final progress = <(int, int)>[];
      final posts = await service.syncPosts(
        config: _config(),
        existingPosts: {'_posts/unchanged.md': existing},
        onProgress: (done, total) => progress.add((done, total)),
      );

      // Only the two changed files were downloaded
      expect(fetchedPaths, hasLength(2));
      expect(fetchedPaths.any((p) => p.endsWith('unchanged.md')), isFalse);

      expect(posts, hasLength(3));
      final byPath = {for (final p in posts) p.filePath: p};
      expect(byPath['_posts/unchanged.md']!.bodyContent, 'cached');
      expect(byPath['_posts/changed.md']!.title, 'Changed');
      expect(byPath['_posts/changed.md']!.fileName, 'changed.md');
      expect(byPath['_posts/2024/added.md']!.fileName, 'added.md');

      expect(progress.first, (0, 2));
      expect(progress.last, (2, 2));
      expect(progress, hasLength(3));
    });

    test('no changed files reports no progress', () async {
      final dio = dioWithResponse((options) {
        return jsonResponse(
          _treesJson(tree: [_blob('_posts/a.md', 'sha_a')]),
          200,
        );
      });
      final service = ContentService(dio: dio);

      final existing = BlogPost(
        sha: 'sha_a',
        fileName: 'a.md',
        filePath: '_posts/a.md',
        title: 'A',
        date: '2026-08-01',
        bodyContent: 'cached',
      );

      final progress = <(int, int)>[];
      final posts = await service.syncPosts(
        config: _config(),
        existingPosts: {'_posts/a.md': existing},
        onProgress: (done, total) => progress.add((done, total)),
      );

      expect(posts.single.bodyContent, 'cached');
      expect(progress, isEmpty);
    });

    test('a failed body fetch keeps the existing post', () async {
      final dio = dioWithResponse((options) {
        if (options.path.contains('/git/trees/')) {
          return jsonResponse(
            _treesJson(tree: [_blob('_posts/a.md', 'sha_new')]),
            200,
          );
        }
        return jsonResponse('{"message":"boom"}', 500);
      });
      final service = ContentService(dio: dio);

      final existing = BlogPost(
        sha: 'sha_old',
        fileName: 'a.md',
        filePath: '_posts/a.md',
        title: 'A',
        date: '2026-08-01',
        bodyContent: 'cached',
      );

      final posts = await service.syncPosts(
        config: _config(),
        existingPosts: {'_posts/a.md': existing},
      );

      expect(posts.single.sha, 'sha_old');
      expect(posts.single.bodyContent, 'cached');
    });
  });
}
