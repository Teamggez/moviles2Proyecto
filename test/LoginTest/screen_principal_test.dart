import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'screen_principal.dart';  
void main() {
  testWidgets('ScreenPrincipal loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScreenPrincipal()));

    expect(find.byType(ScreenPrincipal), findsOneWidget);
    
  });
}
