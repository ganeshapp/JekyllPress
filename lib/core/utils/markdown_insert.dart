/// Pad raw-HTML [block] with the newlines it needs to stand between blank
/// lines when spliced in between [before] and [after]. kramdown only passes
/// HTML through as a block when it is separated from the surrounding text;
/// otherwise the tags end up inside a `<p>`.
String padAsBlock(
  String block, {
  required String before,
  required String after,
}) {
  int newlines(bool Function(String) has) =>
      has('\n\n') ? 2 : (has('\n') ? 1 : 0);
  final lead = before.isEmpty ? '' : '\n' * (2 - newlines(before.endsWith));
  return '$lead$block${'\n' * (2 - newlines(after.startsWith))}';
}
