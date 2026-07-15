import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:clean_connect/main.dart';

void main() {
  testWidgets('EcoWasteApp initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: EcoWasteApp(),
      ),
    );

    // Verify splash screen layout exists (e.g. EcoSystem text)
    expect(find.text('EcoSystem'), findsOneWidget);
    expect(find.text('INITIALIZING'), findsOneWidget);
  });
}
