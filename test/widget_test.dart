import 'package:flutter_test/flutter_test.dart';
import 'package:amray/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our welcome message is displayed.
    expect(find.text('Welcome to Amray'), findsOneWidget);
  });
}
