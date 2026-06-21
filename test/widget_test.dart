import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:breathe_safe/main.dart';

void main() {
  testWidgets('BreatheSafe app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const BreatheSafeApp());
    // Verify the splash screen loads
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
