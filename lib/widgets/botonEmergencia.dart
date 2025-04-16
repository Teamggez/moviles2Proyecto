import 'package:flutter/material.dart';
import '../screens/pantallaEmergencia.dart';

class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key});

  void _confirmEmergency(BuildContext context) async {
    final bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Confirmar emergencia?'),
        content: const Text('¿Deseas abrir el directorio de emergencia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EmergencyDirectoryScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(fontSize: 20),
      ),
      onPressed: () => _confirmEmergency(context),
      child: const Text('¡Emergencia!'),
    );
  }
}
