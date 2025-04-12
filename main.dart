import 'package:flutter/material.dart';
import 'back.dart'; 


void main() {

  runApp(MyApp());
}

// Widget raíz de la aplicación - Con más configuraciones
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alerta Tacna (Seguridad)', // Título más descriptivo
      theme: ThemeData(
        // Paleta de colores principal
        primarySwatch: Colors.indigo, // Un color diferente
        // Color de fondo general de la app
        scaffoldBackgroundColor: Color(0xFFF5F5F5),
        // Estilo para AppBar
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo[700], // Color consistente
          foregroundColor: Colors.white, // Texto e íconos blancos en AppBar
          elevation: 4.0, // Sombra ligera
        ),
      
        cardTheme: CardTheme(
           elevation: 6, // Sombra un poco más pronunciada
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), // Bordes redondeados
        ),

        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.amber[700],
        ),
      
      ),
      // Oculta la cinta "Debug"
      debugShowCheckedModeBanner: false,

      home: AppShell(),

      
    );
  }
}

class AppShell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

    return RiskMapScreen(); // Instancia la pantalla definida en back.dart
  }
}
