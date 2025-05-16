import 'package:flutter/material.dart';
import '../widgets/barralateral.dart';
import '../widgets/LeyendaMapa.dart';
import '../widgets/alternar_boton.dart';
import '../widgets/botonEmergencia.dart';
import 'screen_principal.dart';

class ScreenSecundario extends StatefulWidget {
  const ScreenSecundario({super.key});

  @override
  State<ScreenSecundario> createState() => _ScreenSecundarioState();
}

class _ScreenSecundarioState extends State<ScreenSecundario> {
  bool _isLeyendaVisible = false;
  final double emergencyButtonHeight = 70.0; // Estimación altura botón emergencia + padding
  final double fabSpacing = 10.0;


  void _toggleLeyenda() {
    setState(() {
      _isLeyendaVisible = !_isLeyendaVisible;
    });
  }

  void _closeLeyenda() {
    setState(() {
      _isLeyendaVisible = false;
    });
  }

  void _handleLogout() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _navigateToPrincipalScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const ScreenPrincipal()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: BarraLateral(onLogout: _handleLogout),
      body: Stack(
        children: [
          Container(
            color: Colors.white,
            child: const Center(
              child: Text(
                "Aqui el mapa secundario",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black54),
              ),
            ),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: SafeArea(
              child: Builder(
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 5,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.menu),
                    color: Colors.black54,
                    tooltip: 'Abrir menú',
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.85),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 5,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.info_outline),
                  color: Colors.black54,
                  tooltip: 'Leyenda del mapa',
                  onPressed: _toggleLeyenda,
                ),
              ),
            ),
          ),
          Positioned(
            top: 100,
            right: 20,
            child: SafeArea(
              child: AlternarBoton(
                onPressed: _navigateToPrincipalScreen,
                tooltip: 'Ver mapa principal',
              ),
            ),
          ),
          const Positioned( // Botón de Emergencia
            bottom: 20,
            right: 20, // En la esquina inferior derecha
            child: SafeArea(child: EmergencyButton()),
          ),
          Positioned( // Botón de Rutas (encima del de emergencia)
            bottom: 20 + emergencyButtonHeight + fabSpacing, // Posicionado encima del botón de emergencia
            right: 20,
            child: SafeArea(
              child: FloatingActionButton(
                onPressed: () {
                  print("Botón de Rutas presionado en Secundario");
                },
                backgroundColor: Colors.blue.shade700, // Azul más oscuro
                tooltip: 'Obtener rutas',
                mini: false, // Tamaño normal
                child: const Icon(Icons.directions, color: Colors.white),
              ),
            ),
          ),
          if (_isLeyendaVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeLeyenda,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  child: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                        child: GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.9),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: LeyendaMapa(onClose: _closeLeyenda),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}