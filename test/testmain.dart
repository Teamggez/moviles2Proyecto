import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviles2Proyecto/main.dart';
import 'package:moviles2Proyecto/screens/botonEmergencia.dart';

void main() {
  testWidgets('La app muestra EmergencyButtonScreen al iniciar', (WidgetTester tester) async {
    await tester.pumpWidget(const EmergencyApp());
    expect(find.byType(EmergencyButtonScreen), findsOneWidget);
  });
}
