import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moviles2Proyecto/screens/botonEmergencia.dart';
import 'package:moviles2Proyecto/screens/pantallaEmergencia.dart';

void main() {
  testWidgets('Emergencia: muestra diálogo y navega al directorio si se confirma', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: EmergencyButtonScreen()),
    );

    expect(find.text('¡Emergencia!'), findsOneWidget);

    await tester.tap(find.text('¡Emergencia!'));
    await tester.pumpAndSettle();

    expect(find.text('¿Confirmar emergencia?'), findsOneWidget);
    expect(find.text('¿Deseas abrir el directorio de emergencia?'), findsOneWidget);

    await tester.tap(find.text('Sí'));
    await tester.pumpAndSettle();

    expect(find.byType(EmergencyDirectoryScreen), findsOneWidget);
  });
}
