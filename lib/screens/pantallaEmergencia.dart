import 'package:flutter/material.dart';
import '../services/servicioEmergencia.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyDirectoryScreen extends StatelessWidget {
  const EmergencyDirectoryScreen({super.key});

  void _makeCall(String phoneNumber) async {
    final Uri callUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    } else {
      debugPrint('No se pudo lanzar $phoneNumber');
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = EmergencyService.getEmergencyContacts();

    return Scaffold(
      appBar: AppBar(title: const Text('Directorio de Emergencia')),
      body: ListView.builder(
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return ListTile(
            title: Text(contact['name']!),
            subtitle: Text(contact['phone']!),
            trailing: IconButton(
              icon: const Icon(Icons.call, color: Colors.green),
              onPressed: () => _makeCall(contact['phone']!),
            ),
          );
        },
      ),
    );
  }
}
