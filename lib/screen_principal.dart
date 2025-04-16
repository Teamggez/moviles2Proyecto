import 'package:flutter/material.dart';
import 'widgets/botonEmergencia.dart';

class ScreenPrincipal extends StatefulWidget {
  const ScreenPrincipal({Key? key}) : super(key: key);

  @override
  State<ScreenPrincipal> createState() => _ScreenPrincipalState();
}

class _ScreenPrincipalState extends State<ScreenPrincipal> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Contenido principal centrado
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Pantalla principal',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamedAndRemoveUntil('/', (route) => false);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                  ),
                  child: const Text('Cerrar Sesión'),
                ),
              ],
            ),
          ),

          // Botón de emergencia posicionado en esquina inferior derecha
          Positioned(
            bottom: 20, // Distancia desde el borde inferior
            right: 20, // Distancia desde el borde derecho
            child: const EmergencyButton(),
          ),
        ],
      ),
    );
  }
}
