import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jekyllpress/core/widgets/desktop_content_width.dart';

void main() {
  const content = Key('content');

  /// Pumps the widget in a 1400 px wide window on [platform] and returns the
  /// content's size. The platform override must be cleared before the test
  /// body ends (the binding checks), hence not in a tearDown.
  Future<Size> sizeOn(WidgetTester tester, TargetPlatform platform) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = platform;
    try {
      await tester.pumpWidget(const MaterialApp(
        home: DesktopContentWidth(child: SizedBox.expand(key: content)),
      ));
      return tester.getSize(find.byKey(content));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('caps content at 900 logical px on macOS', (tester) async {
    final size = await sizeOn(tester, TargetPlatform.macOS);
    expect(size.width, DesktopContentWidth.maxWidth);
    expect(size.height, 800, reason: 'only the width is capped');
  });

  testWidgets('caps content at 900 logical px on Linux', (tester) async {
    expect((await sizeOn(tester, TargetPlatform.linux)).width,
        DesktopContentWidth.maxWidth);
  });

  testWidgets('leaves a phone alone', (tester) async {
    expect((await sizeOn(tester, TargetPlatform.android)).width, 1400);
  });
}
