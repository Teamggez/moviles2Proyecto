import 'package:flutter/material.dart';
import '../screens/reporteformulario.dart';
// import '../screens/fake_report_map_screen.dart';

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

        // NUEVO ELEMENTO PARA LA PANTALLA DE REPORTES FALSOS
        // ListTile(
        //   leading: Icon(Icons.map_outlined, color: Colors.orange.shade700),
        //   title: const Text(
        //     'Generar Reportes (Mapa)',
        //     style: TextStyle(fontWeight: FontWeight.w500),
        //   ),
        //   onTap: () {
        //     Navigator.pop(context); // Cierra el drawer
        //     Navigator.push(
        //       context,
        //       MaterialPageRoute(
        //         builder: (context) => const FakeReportMapScreen(), // Navega a la nueva pantalla
        //       ),
        //     );
        //   },
        // ),
        // FIN DEL NUEVO ELEMENTO


          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.warning_amber_outlined),
            title: const Text('Desactivar Alerta'),
            onTap: () {
              Navigator.pop(context);
              // Acción a implementar
            },
          ),
          ListTile(
            leading: const Icon(Icons.pause_circle_outline),
            title: const Text('Suspender Cuenta'),
            onTap: () {
              Navigator.pop(context);
              // Acción a implementar
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Reportar Bug'),
            onTap: () {
              Navigator.pop(context);
              // Acción a implementar
            },
          ),

          const Spacer(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
            ),
            onTap: onLogout,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}