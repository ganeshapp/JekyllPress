import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/models/app_config.dart';
import 'package:jekyllpress/core/services/github_upload_service.dart';

import 'fakes.dart';

AppConfig _config({String branch = 'main'}) {
  return AppConfig(repoOwner: 'gapp', repoName: 'blog', branch: branch);
}

void main() {
  group('GitHubUploadService.uploadPost failure kinds', () {
    test('residual stale-sha conflict is typed PublishErrorKind.conflict',
        () async {
      // Every PUT conflicts and the sha re-fetch cannot read the file,
      // so the retry-once path ends in the stale failure
      final dio = dioWithResponse((options) {
        if (options.method == 'PUT') {
          return jsonResponse('{"message":"is at abc but expected"}', 409);
        }
        return jsonResponse('{"message":"Not Found"}', 404);
      });
      final service = GitHubUploadService(dio: dio);

      final result = await service.uploadPost(
        config: _config(),
        path: '_posts/a.md',
        content: 'body',
        existingSha: 'sha_stale',
      );

      expect(result, isA<UploadFailure>());
      final failure = result as UploadFailure;
      expect(failure.kind, PublishErrorKind.conflict);
      expect(failure.message, contains('changed on GitHub'));
    });

    test('connection errors are typed PublishErrorKind.offline', () async {
      final dio = dioWithError(
        (options) => DioException.connectionError(
          requestOptions: options,
          reason: 'network unreachable',
        ),
      );
      final service = GitHubUploadService(dio: dio);

      final result = await service.uploadPost(
        config: _config(),
        path: '_posts/a.md',
        content: 'body',
      );

      expect(result, isA<UploadFailure>());
      final failure = result as UploadFailure;
      expect(failure.kind, PublishErrorKind.offline);
      expect(failure.message, 'No internet connection');
    });

    test('generic API errors keep PublishErrorKind.generic', () async {
      final dio = dioWithResponse(
          (options) => jsonResponse('{"message":"Validation Failed"}', 422));
      final service = GitHubUploadService(dio: dio);

      final result = await service.uploadPost(
        config: _config(),
        path: '_posts/a.md',
        content: 'body',
      );

      expect((result as UploadFailure).kind, PublishErrorKind.generic);
    });
  });

  group('GitHubUploadService.uploadPost force', () {
    test('force fetches the current sha first and PUTs with it', () async {
      final methods = <String>[];
      String? putSha;
      final dio = dioWithResponse((options) {
        methods.add(options.method);
        if (options.method == 'GET') {
          return jsonResponse(jsonEncode({'sha': 'sha_fresh'}), 200);
        }
        putSha = (options.data as Map)['sha'] as String?;
        return jsonResponse(
            '{"content":{"sha":"sha_new","html_url":"https://x"}}', 200);
      });
      final service = GitHubUploadService(dio: dio);

      final result = await service.uploadPost(
        config: _config(),
        path: '_posts/a.md',
        content: 'body',
        existingSha: 'sha_stale',
        force: true,
      );

      expect(result, isA<UploadSuccess>());
      expect(methods, ['GET', 'PUT']);
      expect(putSha, 'sha_fresh');
    });

    test('force falls back to the stale sha when the fetch fails', () async {
      String? putSha;
      final dio = dioWithResponse((options) {
        if (options.method == 'GET') {
          return jsonResponse('{"message":"Not Found"}', 404);
        }
        putSha = (options.data as Map)['sha'] as String?;
        return jsonResponse(
            '{"content":{"sha":"sha_new","html_url":"https://x"}}', 200);
      });
      final service = GitHubUploadService(dio: dio);

      final result = await service.uploadPost(
        config: _config(),
        path: '_posts/a.md',
        content: 'body',
        existingSha: 'sha_stale',
        force: true,
      );

      expect(result, isA<UploadSuccess>());
      expect(putSha, 'sha_stale');
    });
  });

  group('publishErrorKindOf', () {
    test('classifies connectivity-class DioExceptions as offline', () {
      final options = RequestOptions(path: '/x');
      expect(
        publishErrorKindOf(DioException.connectionError(
            requestOptions: options, reason: 'down')),
        PublishErrorKind.offline,
      );
      expect(
        publishErrorKindOf(DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout)),
        PublishErrorKind.offline,
      );
      expect(
        publishErrorKindOf(DioException(
            requestOptions: options, type: DioExceptionType.badResponse)),
        PublishErrorKind.generic,
      );
      expect(publishErrorKindOf(Exception('boom')), PublishErrorKind.generic);
    });
  });

  group('GitHubUploadService.deleteFile', () {
    test('DELETEs the path with sha, branch, and commit message', () async {
      final requests = <RequestOptions>[];
      final dio = dioWithResponse((options) {
        requests.add(options);
        return jsonResponse('{"content":null,"commit":{"sha":"c1"}}', 200);
      });
      final service = GitHubUploadService(dio: dio);

      final result = await service.deleteFile(
        config: _config(branch: 'dev'),
        path: '_posts/2024-01-01-a.md',
        sha: 'sha_a',
        commitMessage: 'Delete: a.md',
      );

      expect(result, isA<DeleteSuccess>());
      final request = requests.single;
      expect(request.method, 'DELETE');
      expect(request.path, '/repos/gapp/blog/contents/_posts/2024-01-01-a.md');
      final body = request.data as Map<String, dynamic>;
      expect(body['sha'], 'sha_a');
      expect(body['branch'], 'dev');
      expect(body['message'], 'Delete: a.md');
    });

    test('404 counts as success (file already gone)', () async {
      final dio = dioWithResponse(
          (options) => jsonResponse('{"message":"Not Found"}', 404));
      final service = GitHubUploadService(dio: dio);

      final result = await service.deleteFile(
        config: _config(),
        path: '_posts/gone.md',
        sha: 'sha_x',
      );

      expect(result, isA<DeleteSuccess>());
    });

    test('409 stale sha re-fetches the current sha and retries once',
        () async {
      final deleteShas = <String>[];
      final dio = dioWithResponse((options) {
        if (options.method == 'DELETE') {
          final sha = (options.data as Map)['sha'] as String;
          deleteShas.add(sha);
          if (sha == 'sha_stale') {
            return jsonResponse('{"message":"is at abc but expected"}', 409);
          }
          return jsonResponse('{"content":null}', 200);
        }
        // The sha re-fetch
        return jsonResponse(jsonEncode({'sha': 'sha_fresh'}), 200);
      });
      final service = GitHubUploadService(dio: dio);

      final result = await service.deleteFile(
        config: _config(),
        path: '_posts/a.md',
        sha: 'sha_stale',
      );

      expect(result, isA<DeleteSuccess>());
      expect(deleteShas, ['sha_stale', 'sha_fresh']);
    });

    test('409 with an unreadable current sha fails with the stale message',
        () async {
      final dio = dioWithResponse((options) {
        if (options.method == 'DELETE') {
          return jsonResponse('{"message":"conflict"}', 409);
        }
        return jsonResponse('{"message":"Not Found"}', 404);
      });
      final service = GitHubUploadService(dio: dio);

      final result = await service.deleteFile(
        config: _config(),
        path: '_posts/a.md',
        sha: 'sha_stale',
      );

      expect(result, isA<DeleteFailure>());
      expect((result as DeleteFailure).message, contains('Pull to refresh'));
    });

    test('non-conflict errors surface the GitHub message', () async {
      final dio = dioWithResponse(
          (options) => jsonResponse('{"message":"Must have admin rights"}', 403));
      final service = GitHubUploadService(dio: dio);

      final result = await service.deleteFile(
        config: _config(),
        path: '_posts/a.md',
        sha: 'sha_a',
      );

      expect(result, isA<DeleteFailure>());
      expect((result as DeleteFailure).message,
          contains('Must have admin rights'));
    });
  });
}
