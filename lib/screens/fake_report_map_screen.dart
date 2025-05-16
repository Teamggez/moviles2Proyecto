import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'dart:math'; // Para Random

class FakeReportMapScreen extends StatefulWidget {
  const FakeReportMapScreen({super.key});

  @override
  State<FakeReportMapScreen> createState() => _FakeReportMapScreenState();
}

class _FakeReportMapScreenState extends State<FakeReportMapScreen> {
  GoogleMapController? _mapController;
  int _reportCounter = 1;
  bool _isSubmitting = false;
  Set<Marker> _markers = {};

  // Definiciones de categorías y niveles de riesgo (similares a ReporteFormularioScreen)
  final List<Map<String, dynamic>> _allCategories = [
    {'id': 'accident', 'name': 'Accidente'},
    {'id': 'fire', 'name': 'Incendio'},
    {'id': 'roadblock', 'name': 'Vía bloqueada'},
    {'id': 'protest', 'name': 'Manifestación'},
    {'id': 'theft', 'name': 'Robo'},
    {'id': 'assault', 'name': 'Asalto'},
    {'id': 'violence', 'name': 'Violencia'},
    {'id': 'vandalism', 'name': 'Vandalismo'},
    // 'others' se excluye para la generación aleatoria
  ];

  final List<String> _riskLevelOptions = [
    'Bajo',
    'Medio',
    'Alto'
  ];

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(-18.0146, -70.2534), // Coordenadas de ejemplo (Tacna)
    zoom: 13.0,
  );

  Future<void> _handleMapTap(LatLng position) async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _markers = {
        Marker(
          markerId: MarkerId(position.toString()),
          position: position,
          infoWindow: const InfoWindow(title: 'Generando reporte...'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        )
      };
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context); // Cache ScaffoldMessenger

    try {
      final String reportTitle = "ReporteTest$_reportCounter";
      
      // Seleccionar tipo aleatorio (excluyendo 'otros')
      final randomCategory = _allCategories[Random().nextInt(_allCategories.length)];
      final String selectedCategoryType = randomCategory['id'];

      // Seleccionar nivel de riesgo aleatorio
      final String randomRiskLevel = _riskLevelOptions[Random().nextInt(_riskLevelOptions.length)];

      final reporteData = {
        'id': const Uuid().v4(),
        'tipo': selectedCategoryType,
        'titulo': reportTitle,
        'descripcion': 'Reporte de prueba generado automáticamente desde el mapa.',
        'nivelRiesgo': randomRiskLevel,
        'ubicacion': {
          'latitud': position.latitude,
          'longitud': position.longitude
        },
        'imagenes': [], // O null, según tu modelo de datos
        'fechaCreacion': FieldValue.serverTimestamp(),
        'fechaCreacionLocal': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        'estado': 'Activo',
        'etapa': 'pendiente',
      };

      await FirebaseFirestore.instance.collection('Reportes').add(reporteData);

      setState(() {
        _reportCounter++;
        _isSubmitting = false;
        // Opcional: Limpiar el marcador o cambiar su info window
         _markers = {
          Marker(
            markerId: MarkerId(position.toString()),
            position: position,
            infoWindow: InfoWindow(title: '$reportTitle enviado!', snippet: 'Lat: ${position.latitude.toStringAsFixed(4)}, Lng: ${position.longitude.toStringAsFixed(4)}'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          )
        };
      });

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('$reportTitle enviado con éxito a Firebase.'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _markers = {
            Marker(
              markerId: MarkerId(position.toString()),
              position: position,
              infoWindow: const InfoWindow(title: 'Error al enviar'),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            )
          };
        });
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error al enviar el reporte: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generar Reportes Falsos'),
        backgroundColor: Colors.indigo[700],
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: _kInitialPosition,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
        onTap: _handleMapTap,
        markers: _markers,
        zoomControlsEnabled: true,
        myLocationButtonEnabled: true, // Puede ser útil para navegar el mapa
        myLocationEnabled: true, // Puede requerir permisos de ubicación
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Muestra un diálogo de ayuda o instrucciones
           showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Instrucciones'),
              content: const Text('Presiona en cualquier punto del mapa para generar y enviar un reporte de prueba a Firebase con datos aleatorios.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        },
        label: const Text('Ayuda'),
        icon: const Icon(Icons.info_outline),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}