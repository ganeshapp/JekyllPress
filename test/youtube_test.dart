import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/utils/youtube.dart';

void main() {
  group('parseYouTubeUrl', () {
    const id = 'dQw4w9WgXcQ';

    test('recognises every supported link shape', () {
      const regular = {
        'https://www.youtube.com/watch?v=$id',
        'https://www.youtube.com/watch?v=$id&list=PL123&index=2',
        'https://youtube.com/watch?feature=share&v=$id',
        'http://youtube.com/watch?v=$id',
        'HTTPS://WWW.YOUTUBE.COM/watch?v=$id',
        'youtube.com/watch?v=$id',
        'www.youtube.com/watch?v=$id',
        'm.youtube.com/watch?v=$id',
        'https://youtu.be/$id',
        'https://youtu.be/$id?si=AbCdEf',
        'youtu.be/$id',
        'https://www.youtube.com/embed/$id?si=AbCdEf',
        'https://www.youtube.com/live/$id?feature=share',
        '  https://youtu.be/$id  ',
      };
      for (final url in regular) {
        expect(
          parseYouTubeUrl(url),
          (id: id, isShort: false, start: null),
          reason: url,
        );
      }

      for (final url in {
        'https://www.youtube.com/shorts/$id',
        'youtube.com/shorts/$id/',
        'https://m.youtube.com/shorts/$id?feature=share',
      }) {
        expect(
          parseYouTubeUrl(url),
          (id: id, isShort: true, start: null),
          reason: url,
        );
      }

      expect(parseYouTubeUrl('youtu.be/a-b_c-d_e-f')?.id, 'a-b_c-d_e-f');
    });

    test('reads the start time from t= or start=', () {
      const starts = {
        'https://youtu.be/$id?t=90': 90,
        'https://youtu.be/$id?t=90s': 90,
        'https://youtu.be/$id?si=x&t=1m30s': 90,
        'https://www.youtube.com/watch?v=$id&t=1h2m3s': 3723,
        'https://www.youtube.com/watch?v=$id&t=2m': 120,
        'https://www.youtube.com/embed/$id?start=45': 45,
      };
      starts.forEach((url, seconds) {
        expect(parseYouTubeUrl(url)?.start, seconds, reason: url);
      });

      // Zero or garbage: still the video, just no start time
      for (final url in {
        'https://youtu.be/$id?t=0',
        'https://youtu.be/$id?t=abc',
        'https://youtu.be/$id?t=1s30m',
        'https://youtu.be/$id?t=99999999999999999999',
      }) {
        expect(
          parseYouTubeUrl(url),
          (id: id, isShort: false, start: null),
          reason: url,
        );
      }
    });

    test('rejects anything that is not a single YouTube video', () {
      const rejected = {
        '',
        'not a link',
        id,
        'javascript:alert(1)',
        'ftp://youtube.com/watch?v=$id',
        'https://vimeo.com/76979871',
        'https://notyoutube.com/watch?v=$id',
        'https://youtube.com.evil.com/watch?v=$id',
        'https://youtube.com@evil.com/watch?v=$id',
        'https://evil.com@youtube.com/watch?v=$id',
        'https://music.youtube.com/watch?v=$id',
        'https://www.youtube.com/watch',
        'https://www.youtube.com/watch?v=short',
        'https://www.youtube.com/watch?v=${id}X',
        'https://www.youtube.com/watch?v=$id"><script>',
        'https://www.youtube.com/playlist?list=PL123',
        'https://www.youtube.com/@somechannel',
        'https://www.youtube.com/shorts/',
        'https://youtu.be/$id/extra',
        // Malformed %-escapes must not throw
        'https://youtu.be/%FF',
        'https://example.com/caf%E9',
        'https://youtu.be/$id?t=%FF',
      };
      for (final input in rejected) {
        expect(parseYouTubeUrl(input), isNull, reason: input);
      }
    });
  });

  group('youTubeEmbed', () {
    test('regular video', () {
      expect(
        youTubeEmbed((id: 'dQw4w9WgXcQ', isShort: false, start: null)),
        '''
<div style="text-align: center;">
  <iframe width="560" height="315" src="https://www.youtube.com/embed/dQw4w9WgXcQ" title="YouTube video player" style="width: 100%; height: auto; aspect-ratio: 16 / 9; border: 0; border-radius: 12px;" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen loading="lazy"></iframe>
</div>''',
      );
    });

    test('start time is appended to the player URL', () {
      expect(
        youTubeEmbed((id: 'dQw4w9WgXcQ', isShort: false, start: 90)),
        contains('src="https://www.youtube.com/embed/dQw4w9WgXcQ?start=90"'),
      );
    });

    test('Shorts get a portrait frame', () {
      expect(
        youTubeEmbed((id: 'aBcDeFgHiJk', isShort: true, start: null)),
        '''
<div style="text-align: center;">
  <iframe width="315" height="560" src="https://www.youtube.com/embed/aBcDeFgHiJk" title="YouTube video player" style="width: 100%; max-width: 360px; height: auto; aspect-ratio: 9 / 16; border: 0; border-radius: 12px;" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen loading="lazy"></iframe>
</div>''',
      );
    });
  });
}
