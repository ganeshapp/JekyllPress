import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter binds Tab to NextFocusIntent on every platform (and on macOS
/// routes the native insertTab: selector there too), so in the editor's
/// body field Tab moved focus to the toolbar instead of indenting a nested
/// list item. The editor answers NextFocusIntent itself while the body has
/// focus; this harness mirrors that mapping.
Widget _harness(TextEditingController controller, FocusNode focus) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          TextField(key: const Key('title')),
          Actions(
            actions: {
              NextFocusIntent: CallbackAction<NextFocusIntent>(
                onInvoke: (_) {
                  final s = controller.selection;
                  controller.value = TextEditingValue(
                    text: controller.text.replaceRange(s.start, s.end, '  '),
                    selection: TextSelection.collapsed(offset: s.start + 2),
                  );
                  return null;
                },
              ),
            },
            child: TextField(
              key: const Key('body'),
              controller: controller,
              focusNode: focus,
              maxLines: null,
            ),
          ),
          const TextField(key: Key('after')),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('Tab in the body inserts two spaces and keeps focus',
      (tester) async {
    final controller = TextEditingController(text: '- item\n- nested');
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(_harness(controller, focus));

    await tester.tap(find.byKey(const Key('body')));
    await tester.pump();
    controller.selection = const TextSelection.collapsed(offset: 7);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(controller.text, '- item\n  - nested');
    expect(controller.selection.baseOffset, 9);
    expect(focus.hasFocus, isTrue);
  });

  testWidgets('Shift+Tab still leaves the body (keyboard users can get out)',
      (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(_harness(controller, focus));

    await tester.tap(find.byKey(const Key('body')));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(focus.hasFocus, isFalse);
  });

  testWidgets('Tab in another field still moves focus', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(_harness(controller, focus));

    await tester.tap(find.byKey(const Key('title')));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(focus.hasFocus, isTrue, reason: 'title -> body');
    expect(controller.text, isEmpty);
  });
}
