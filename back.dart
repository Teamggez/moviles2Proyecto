// File: back.dart
import 'package:flutter/material.dart';

// Definimos aquí el StatefulWidget y su State asociado, que contiene la lógica.
class RiskMapScreen extends StatefulWidget {
  @override
  _RiskMapScreenState createState() => _RiskMapScreenState();
}

// Clase State: Maneja las variables y la lógica de interacción
class _RiskMapScreenState extends State<RiskMapScreen> {
  // Variables de estado (La "información" que maneja nuestro conceptual 'back')
  String? dangerType;
  String? riskLevel;
  String? lastUpdated;
  String? safetyRecommendations;
  bool isPopupVisible = false;
  double tapX = 0.0;
  double tapY = 0.0;

  // Método que maneja el toque (Lógica principal de esta pantalla)
  void _onTap(Offset position) {
    // --- Inicio Lógica ---
    setState(() {
      tapX = position.dx;
      tapY = position.dy;

      // Simulación de lógica para determinar datos de riesgo
      dangerType = 'Robo';
      lastUpdated = '2025-04-11 19:55'; // Puedes usar DateTime.now()
      safetyRecommendations = 'Cuidado con tus pertenencias en esta zona.';

      if (position.dx > 150 && position.dx < 300) {
        riskLevel = 'Peligroso';
      } else if (position.dy > 100 && position.dy < 250) {
        riskLevel = 'Medio';
      } else {
        riskLevel = 'Seguro';
      }
      isPopupVisible = (riskLevel != null); // Mostrar popup si hay riesgo
    });
     // --- Fin Lógica ---
  }

  // Método para cerrar el popup (Lógica)
  void _closePopup() {
    setState(() {
      isPopupVisible = false;
    });
  }

  // El método build sigue siendo necesario aquí para construir la UI
  // asociada a ESTE estado específico.
  @override
  Widget build(BuildContext context) {
    // Calcular estilo visual basado en el estado actual
    double circleSize = 60;
    Color circleColor = Colors.green.withOpacity(0.6);
    if (riskLevel == 'Peligroso') {
      circleSize = 80; circleColor = Colors.red.withOpacity(0.6);
    } else if (riskLevel == 'Medio') {
      circleSize = 70; circleColor = Colors.yellow.withOpacity(0.6);
    }

    // Retorna la estructura visual (UI)
    return Scaffold(
      appBar: AppBar(
        title: Text("Mapa de Riesgo (State en back.dart)"),
      ),
      body: Stack(
        children: [
          // --- Parte Visual (UI) ---
          // Mapa con GestureDetector que llama a _onTap
          GestureDetector(
            onTapUp: (TapUpDetails details) => _onTap(details.localPosition),
            child: Container( /* ... Contenedor del mapa ... */
               color: Colors.blueGrey, height: 400, width: double.infinity,
               child: Center(child: Icon(Icons.map, color: Colors.white, size: 50)),
             ),
          ),
          // Círculo visual
          if (tapX != 0.0 && tapY != 0.0 && riskLevel != null)
            Positioned( /* ... Círculo ... */
              left: tapX - (circleSize / 2), top: tapY - (circleSize / 2),
              child: Container(
                 width: circleSize, height: circleSize,
                 decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle, border: Border.all(color: circleColor, width: 2)),
               ),
            ),
          // Tarjeta de detalles
          if (isPopupVisible && riskLevel != null)
            Positioned( /* ... Tarjeta ... */
              bottom: 20, left: 10, right: 10,
              child: Card( /* ... Contenido de la tarjeta ... */
                 elevation: 8, color: Colors.white,
                 child: Padding(
                   padding: const EdgeInsets.all(16.0),
                   child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                       Text('Tipo de Peligro: ${dangerType ?? '-'}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), SizedBox(height: 8),
                       Text('Nivel de Riesgo: ${riskLevel!}', style: TextStyle(fontSize: 16)), SizedBox(height: 8),
                       Text('Última Actualización: ${lastUpdated ?? '-'}', style: TextStyle(fontSize: 16)), SizedBox(height: 8),
                       Text('Recomendaciones: ${safetyRecommendations ?? '-'}', style: TextStyle(fontSize: 16)), SizedBox(height: 12),
                       Align(alignment: Alignment.centerRight, child: IconButton(icon: Icon(Icons.close), onPressed: _closePopup))
                     ],
                   ),
                 ),
               ),
            ),
        ],
      ),
    );
  }
}
