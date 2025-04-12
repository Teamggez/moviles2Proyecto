import 'package:flutter/material.dart';
import 'screens/botonEmergencia.dart';

void main() {
  runApp(const EmergencyApp());
}

class EmergencyApp extends StatelessWidget {
  const EmergencyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency App',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const EmergencyButtonScreen(),
    );
  }
}
