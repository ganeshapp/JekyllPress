import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jekyllpress/main.dart';

void main() {
  testWidgets('App starts and shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: JekyllPressApp(),
      ),
    );

    // App should load and show login screen or splash
    expect(find.text('JekyllPress'), findsWidgets);
  });
}
