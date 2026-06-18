import 'package:flutter_test/flutter_test.dart';
import 'package:gem/src/app.dart';

void main() {
  testWidgets('Gem Launcher smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app logo or title is rendered.
    expect(find.text('Gem'), findsOneWidget);
  });
}
