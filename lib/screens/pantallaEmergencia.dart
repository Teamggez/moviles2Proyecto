import 'package:flutter/material.dart';
import '../services/servicioEmergencia.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyDirectoryScreen extends StatefulWidget {
  const EmergencyDirectoryScreen({super.key});

  @override
  State<EmergencyDirectoryScreen> createState() =>
      _EmergencyDirectoryScreenState();
}

class _EmergencyDirectoryScreenState extends State<EmergencyDirectoryScreen> {
  final EmergencyService emergencyService = EmergencyService();

  void _makeCall(String phoneNumber, BuildContext context) async {
    final String sanitizedPhoneNumber =
        phoneNumber.replaceAll(RegExp(r'[()\s]'), '');
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

  Future<void> _showEditContactDialog(
      BuildContext context, Map<String, dynamic> contact) async {
    final nameController = TextEditingController(text: contact['name']);
    final phoneController = TextEditingController(text: contact['phone']);

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar Contacto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isNotEmpty && phone.isNotEmpty) {
                  emergencyService.updateEmergencyContact(
                    id: contact['id'],
                    name: name,
                    phone: phone,
                    icon: contact['icon'],
                    isPersonal: contact['isPersonal'],
                  );
                  if (context.mounted) {
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$name actualizado correctamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.of(context).pop();
                  }
                }
              },
              child: const Text('Guardar'),
            )
          ],
        );
      },
    );
  }

  Future<void> _showAddContactDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar Contacto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: Navigator.of(context).pop,
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final phone = phoneController.text.trim();
                if (name.isNotEmpty && phone.isNotEmpty) {
                  emergencyService.addEmergencyContact(
                    name: name,
                    phone: phone,
                    icon: Icons.person_add_alt_1,
                    isPersonal: true,
                  );

                  if (context.mounted) {
                    setState(() {}); // Recargar UI
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$name agregado correctamente'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    Navigator.of(context).pop(); // Cerrar diálogo
                  }
                }
              },
              child: const Text('Agregar'),
            )
          ],
        );
      },
    );
  }

  void _deleteContact(int index) {
    emergencyService.deleteEmergencyContact(index);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contacts = emergencyService.getEmergencyContacts();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Directorio de Emergencia',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
          final IconData iconData =
              contact['icon'] as IconData? ?? Icons.contact_phone;

          return Card(
            elevation: 2.0,
            margin: EdgeInsets.zero,
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.call_outlined,
                      color: theme.primaryColor,
                      size: 28,
                    ),
                    tooltip: 'Llamar a ${contact['name']}',
                    onPressed: () => _makeCall(contact['phone']!, context),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => _showEditContactDialog(context, contact),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 28,
                    ),
                    tooltip: 'Eliminar contacto',
                    onPressed: () {
                      _deleteContact(index);
                    },
                  ),
                ],
              ),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
            ),
          );
        },
        separatorBuilder: (context, index) {
          bool nextIsPersonal = false;
          if (index + 1 < contacts.length) {
            nextIsPersonal = contacts[index + 1]['isPersonal'] == true;
          }
          bool currentIsPersonal = contacts[index]['isPersonal'] == true;

          if (!currentIsPersonal && nextIsPersonal) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.black26,
              ),
            );
          } else {
            return const SizedBox(height: 12.0);
          }
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddContactDialog(context),
        label: const Text('Agregar'),
        icon: const Icon(Icons.add),
        backgroundColor: theme.primaryColor,
      ),
    );
  }
}
