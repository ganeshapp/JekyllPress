import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The editor's body field must place the caret on a plain tap, never extend a
/// selection from the previous caret to the tap point.
///
/// Flutter extends the selection when it believes Shift is held. That state can
/// get stuck on a device (paired Bluetooth keyboard, or an IME emitting a Shift
/// press with no matching release), which turns every tap in a long post into a
/// select-everything-in-between. The editor guards against it in
/// `_collapseCaretAfterTap`; this pins that behaviour down.
const _body =
    'Working out to directionally be healthy can be ultra boring. You can '
    'subscribe to systems or design your own workouts (cardio on Monday, '
    'upper body on Tuesdays, etc.)';

/// Mirrors the editor's guard.
void collapseCaretAfterTap(TextEditingController controller) {
  final selection = controller.selection;
  if (!selection.isValid || selection.isCollapsed) return;
  controller.selection =
      TextSelection.collapsed(offset: selection.extentOffset);
}

Widget _harness(TextEditingController controller) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              scrollController: ScrollController(),
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              onTap: () => collapseCaretAfterTap(controller),
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  test('the guard collapses an extended selection to the tap point', () {
    final controller = TextEditingController(text: _body);
    addTearDown(controller.dispose);

    // What a stuck Shift produces: anchored at the old caret (end of the
    // post), extended to wherever the user tapped.
    controller.selection = TextSelection(
      baseOffset: _body.length,
      extentOffset: 89,
    );

    collapseCaretAfterTap(controller);

    expect(controller.selection.isCollapsed, isTrue);
    expect(
      controller.selection.baseOffset,
      89,
      reason: 'The caret must land where the user tapped, not at the anchor.',
    );
  });

  test('the guard leaves an already-collapsed caret alone', () {
    final controller = TextEditingController(text: _body);
    addTearDown(controller.dispose);
    controller.selection = const TextSelection.collapsed(offset: 42);

    collapseCaretAfterTap(controller);

    expect(controller.selection.baseOffset, 42);
  });

  test('the guard ignores an invalid selection (field never focused)', () {
    final controller = TextEditingController(text: _body);
    addTearDown(controller.dispose);

    collapseCaretAfterTap(controller);

    expect(controller.selection.isValid, isFalse);
  });

  testWidgets('a plain tap on an earlier line leaves a collapsed caret',
      (tester) async {
    final controller = TextEditingController(text: _body);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    controller.selection = TextSelection.collapsed(offset: _body.length);
    await tester.pumpAndSettle();

    final box = tester.getRect(find.byType(TextField));
    await tester.tapAt(Offset(box.left + 40, box.top + 12));
    await tester.pumpAndSettle();

    expect(controller.selection.isCollapsed, isTrue,
        reason: 'Got ${controller.selection}');
  });

  testWidgets('double-tap still selects a word (guard must not eat it)',
      (tester) async {
    final controller = TextEditingController(text: _body);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_harness(controller));
    await tester.pumpAndSettle();

    final box = tester.getRect(find.byType(TextField));
    final target = Offset(box.left + 40, box.top + 12);

    // Two taps inside the double-tap timeout. onTap fires only on the first,
    // so the word selection produced by the second must survive.
    await tester.tapAt(target);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(target);
    await tester.pumpAndSettle();

    expect(
      controller.selection.isCollapsed,
      isFalse,
      reason: 'Double-tap should still select a word. '
          'Got ${controller.selection}',
    );
  });
}
