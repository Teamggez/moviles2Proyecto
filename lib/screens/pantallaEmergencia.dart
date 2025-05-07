// EmergencyDirectoryScreen.dart

import 'package:flutter/material.dart';
import '../services/servicioEmergencia.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyDirectoryScreen extends StatelessWidget {
  const EmergencyDirectoryScreen({super.key});

  void _makeCall(String phoneNumber, BuildContext context) async {
    final String sanitizedPhoneNumber = phoneNumber.replaceAll(RegExp(r'[()\s]'), '');
    final Uri callUri = Uri(scheme: 'tel', path: sanitizedPhoneNumber);
    try {
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
      } else {
        if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo iniciar la llamada a $phoneNumber'),
              backgroundColor: Colors.red,
            ),
          );
        }
        debugPrint('No se pudo lanzar $callUri');
      }
    } catch (e) {
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al intentar llamar: $e'),
              backgroundColor: Colors.red,
            ),
          );
       }
       debugPrint('Error al lanzar $callUri: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contacts = EmergencyService.getEmergencyContacts();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
            'Directorio de Emergencia',
             style: TextStyle(
                 color: Colors.white,
                 fontWeight: FontWeight.bold
             )
        ),
        backgroundColor: theme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      backgroundColor: Colors.grey[100],
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          final IconData iconData = contact['icon'] as IconData? ?? Icons.contact_phone;

          return Card(
            elevation: 2.0,
            margin: EdgeInsets.zero, // Margin is handled by separator padding or bottom margin of Card
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: ListTile(
              leading: CircleAvatar(
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  child: Icon(
                    iconData,
                    color: theme.primaryColor,
                    size: 24,
                  ),
              ),
              title: Text(
                contact['name']!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Color(0xFF334155),
                ),
              ),
              subtitle: Text(
                contact['phone']!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.call_outlined,
                  color: theme.primaryColor,
                  size: 28,
                ),
                tooltip: 'Llamar a ${contact['name']}',
                onPressed: () => _makeCall(contact['phone']!, context),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            ),
          );
        },
        separatorBuilder: (context, index) {
          // Check if the *next* item is personal and the current one is not
          bool nextIsPersonal = false;
          if (index + 1 < contacts.length) {
            nextIsPersonal = contacts[index + 1]['isPersonal'] == true;
          }
          bool currentIsPersonal = contacts[index]['isPersonal'] == true;

          if (!currentIsPersonal && nextIsPersonal) {
            // Add a Divider with padding before the personal contact section
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0), // Padding around divider
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.black26, // Slightly visible divider color
              ),
            );
          } else {
            // Standard vertical space between cards
            return const SizedBox(height: 12.0);
          }
        },
      ),
    );
  }
}