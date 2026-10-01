import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/utils/markdown_insert.dart';

/// The body after inserting block `B` between [before] and [after]
String insert(String before, String after) =>
    '$before${padAsBlock('B', before: before, after: after)}$after';

void main() {
  group('padAsBlock leaves the block between blank lines', () {
    test('empty post', () {
      expect(insert('', ''), 'B\n\n');
    });

    test('start of the post', () {
      expect(insert('', 'Text'), 'B\n\nText');
    });

    test('end of a paragraph at the end of the post', () {
      expect(insert('Para', ''), 'Para\n\nB\n\n');
      expect(insert('Para\n', ''), 'Para\n\nB\n\n');
      expect(insert('Para\n\n', ''), 'Para\n\nB\n\n');
    });

    test('middle of a line splits the paragraph', () {
      expect(insert('Hello ', 'world'), 'Hello \n\nB\n\nworld');
    });

    test('existing newlines are reused, not doubled', () {
      expect(insert('One', '\nTwo'), 'One\n\nB\n\nTwo');
      expect(insert('One\n', 'Two'), 'One\n\nB\n\nTwo');
      expect(insert('One\n\n', '\n\nTwo'), 'One\n\nB\n\nTwo');
    });
  });
}
