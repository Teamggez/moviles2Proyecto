import 'package:flutter/material.dart';
import '../screens/reporteformulario.dart';
import '../screens/alert_settings_screen.dart';
import '../screens/fake_report_map_screen.dart';

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
          
          ListTile(
            leading: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
            title: const Text('Reportar Incidente (Formulario)', 
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReporteFormularioScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.settings_outlined, color: Colors.green.shade700),
            title: const Text('Configuración de Alertas', 
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlertSettingsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: Icon(Icons.map_outlined, color: Colors.purple.shade700),
            title: const Text('Generar Reportes (Mapa)', 
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FakeReportMapScreen(),
                ),
              );
            },
          ),

          const Spacer(),
          
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar Sesión'),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}
