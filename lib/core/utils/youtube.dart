/// YouTube links -> the player embed JekyllPress inserts into posts.
library;

/// A recognised YouTube video; [start] is in seconds.
typedef YouTubeVideo = ({String id, bool isShort, int? start});

/// Also what keeps [youTubeEmbed] injection-safe: the id is the only user
/// text that reaches the HTML.
final _idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

/// Matched exactly, so look-alikes (notyoutube.com, youtube.com.evil.com)
/// never pass.
const _hosts = {'youtube.com', 'www.youtube.com', 'm.youtube.com'};

/// `youtube.com/<prefix>/<id>` paths
const _idPrefixes = {'shorts', 'embed', 'live'};

/// `90`, `90s`, `1m30s`, `1h2m3s`; digits capped so int.parse can't overflow
final _timePattern = RegExp(
  r'^(?:(\d{1,6})h)?(?:(\d{1,6})m)?(?:(\d{1,6})s?)?$',
);

/// Recognise a link to a single YouTube video (watch, youtu.be, shorts,
/// embed or live; scheme optional). Null for anything else.
YouTubeVideo? parseYouTubeUrl(String input) {
  final text = input.trim();
  final uri = Uri.tryParse(
    text.startsWith(RegExp('https?://', caseSensitive: false))
        ? text
        : 'https://$text',
  );
  if (uri == null || uri.userInfo.isNotEmpty) return null;

  final path = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  String? id;
  var isShort = false;
  if (uri.host == 'youtu.be' && path.length == 1) {
    id = path[0];
  } else if (_hosts.contains(uri.host)) {
    if (path.length == 1 && path[0] == 'watch') {
      id = uri.queryParameters['v'];
    } else if (path.length == 2 && _idPrefixes.contains(path[0])) {
      id = path[1];
      isShort = path[0] == 'shorts';
    }
  }
  if (id == null || !_idPattern.hasMatch(id)) return null;

  final time = _timePattern.firstMatch(
    uri.queryParameters['t'] ?? uri.queryParameters['start'] ?? '',
  );
  int part(int group) => int.parse(time?.group(group) ?? '0');
  final start = part(1) * 3600 + part(2) * 60 + part(3);
  return (id: id, isShort: isShort, start: start > 0 ? start : null);
}

/// The player snippet for a post. Shorts get a portrait frame capped at
/// 360px so they don't fill a desktop screen.
String youTubeEmbed(YouTubeVideo video) {
  final (size, shape) =
      video.isShort
          ? (
            'width="315" height="560"',
            'max-width: 360px; height: auto; aspect-ratio: 9 / 16',
          )
          : ('width="560" height="315"', 'height: auto; aspect-ratio: 16 / 9');
  final start = video.start == null ? '' : '?start=${video.start}';
  return '<div style="text-align: center;">\n'
      '  <iframe $size src="https://www.youtube.com/embed/${video.id}$start" '
      'title="YouTube video player" '
      'style="width: 100%; $shape; border: 0; border-radius: 12px;" '
      'allow="accelerometer; autoplay; clipboard-write; encrypted-media; '
      'gyroscope; picture-in-picture; web-share" '
      'referrerpolicy="strict-origin-when-cross-origin" '
      'allowfullscreen loading="lazy"></iframe>\n'
      '</div>';
}
