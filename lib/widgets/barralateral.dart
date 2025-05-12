import 'package:flutter/material.dart';
import '../screens/reporteformulario.dart';

class BarraLateral extends StatelessWidget {
  final VoidCallback onLogout;

  const BarraLateral({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.indigo[700],
            ),
            child: const Row(
              children: [
                Icon(Icons.security, size: 40, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Reportes Ciudadanos',
                  style: TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          // Elemento para reportar incidente (ahora navega directamente)
          ListTile(
            leading: const Icon(Icons.add_circle, color: Colors.blue),
            title: const Text('Reportar Incidente', 
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              Navigator.pop(context); // Cierra el drawer
              // Navega directamente al formulario de reporte
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReporteFormularioScreen(),
                ),
              );
            },
          ),
          
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.warning_amber),
            title: const Text('Desactivar Alerta'),
            onTap: () {
              Navigator.pop(context);
              // Acción a implementar
            },
          ),
          ListTile(
            leading: const Icon(Icons.pause_circle),
            title: const Text('Suspender Cuenta'),
            onTap: () {
              Navigator.pop(context);
              // Acción a implementar
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report),
            title: const Text('Reportar Bug'),
            onTap: () {
              Navigator.pop(context);
              // Acción a implementar
            },
          ),

          const Spacer(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: onLogout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}