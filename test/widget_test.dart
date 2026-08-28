import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:clean_connect/main.dart';

void main() {
  testWidgets('CleanConnectApp initialization smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: CleanConnectApp(),
      ),
    );

    // Verify splash screen layout exists (e.g. CleanConnect text)
    expect(find.text('CleanConnect'), findsWidgets);

    // Drain timers
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
