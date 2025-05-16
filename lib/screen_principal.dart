import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/botonEmergencia.dart';
import 'widgets/barralateral.dart';
import 'widgets/LeyendaMapa.dart';
import 'package:geolocator/geolocator.dart';

enum MapDisplayMode {
  interactiveTap,
  heatmapFromFirebase,
}


class ScreenPrincipal extends StatefulWidget {
  const ScreenPrincipal({super.key});

  @override
  State<ScreenPrincipal> createState() => _ScreenPrincipalState();
}

class _ScreenPrincipalState extends State<ScreenPrincipal>
    with SingleTickerProviderStateMixin {
  // Variables para el modo interactivo (toque)
  String? dangerTypeInteractive;
  String? riskLevelInteractive;
  String? lastUpdatedInteractive;
  String? safetyRecommendationsInteractive;
  bool isPopupInteractiveVisible = false;

  bool isLeyendaVisible = false;

  // Variable de estado para el modo de mapa actual
  MapDisplayMode _currentMapMode = MapDisplayMode.interactiveTap;
  // Variable para indicar si se están cargando los datos del heatmap
  bool _isLoadingHeatmapData = false;
  // Lista para almacenar los datos de reportes para el heatmap
  List<Map<String, dynamic>> _heatmapReportData = [];

  // Set para los círculos (usado para reportes en modo heatmap y para el círculo de toque interactivo)
  Set<Circle> circles = {};
  // Set para los polígonos (usado para los cuadrados verdes base en modo heatmap)
  Set<Polygon> polygons = {};

  GoogleMapController? _mapController;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack));
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1), // Empieza desde abajo
      end: Offset.zero, // Termina en su posición original
    ).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // Posición inicial del mapa (Tacna)
  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(-18.0146, -70.2534),
    zoom: 13.0,
  );

  // Manejador de toques en el mapa
  void _onMapTap(LatLng position) {
    if (isLeyendaVisible) {
      setState(() {
        isLeyendaVisible = false;
      });
      return;
    }

    if (_currentMapMode == MapDisplayMode.interactiveTap) {
      _handleInteractiveTap(position);
    } else if (_currentMapMode == MapDisplayMode.heatmapFromFirebase) {
      if (isPopupInteractiveVisible) {
        _closeInteractivePopup();
      }
      print("Mapa tocado en modo heatmap de Firebase. Posición: $position");
    }
  }

  // Lógica para el modo de toque interactivo (simulado)
  void _handleInteractiveTap(LatLng position) {
    setState(() {
      dangerTypeInteractive = 'Robo (Simulado)';
      // MODIFICADO: Revertido a la forma simple de mostrar hora y minuto
      lastUpdatedInteractive =
          'Actualizado: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
      safetyRecommendationsInteractive =
          'Cuidado con tus pertenencias en esta zona (simulado).';

      double lat = position.latitude;
      double lng = position.longitude;

      if (lat > -18.01 && lat < -17.99 && lng > -70.25 && lng < -70.23) {
        riskLevelInteractive = 'Peligroso';
      } else if (lng > -70.26 &&
          lng < -70.24 &&
          lat > -18.03 &&
          lat < -18.00) {
        riskLevelInteractive = 'Medio';
      } else {
        riskLevelInteractive = 'Seguro';
      }

      _addInteractiveCircle(position, riskLevelInteractive);
      isPopupInteractiveVisible = true;
      _animationController.reset();
      _animationController.forward();
    });
  }

  // Añade el círculo para el modo de toque interactivo
  void _addInteractiveCircle(LatLng position, String? currentRiskLevelForTap) {
    Color circleColor = Colors.green.withAlpha(153);
    double circleRadius = 60.0;

    if (currentRiskLevelForTap == 'Peligroso') {
      circleColor = Colors.red.withAlpha(153);
      circleRadius = 80.0;
    } else if (currentRiskLevelForTap == 'Medio') {
      circleColor = Colors.orange.withAlpha(153);
      circleRadius = 70.0;
    }

    Circle circle = Circle(
      circleId: CircleId("interactive_tap_${position.toString()}"),
      center: position,
      radius: circleRadius,
      fillColor: circleColor,
      strokeColor: circleColor.withAlpha(204),
      strokeWidth: 0,
    );
    
    setState(() {
      circles.clear();
      polygons.clear(); 
      circles.add(circle);
    });
  }

  // Cierra el popup del modo interactivo
  void _closeInteractivePopup() {
    _animationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          isPopupInteractiveVisible = false;
          if (_currentMapMode == MapDisplayMode.interactiveTap) {
            circles.clear();
            polygons.clear(); 
            riskLevelInteractive = null;
          }
        });
      }
    });
  }

  // Carga los datos de reportes desde Firebase y los muestra
  Future<void> _loadAndDisplayHeatmapData() async {
    if (!mounted) return;
    setState(() {
      _isLoadingHeatmapData = true;
      circles.clear(); 
      polygons.clear(); 
      if (isPopupInteractiveVisible) _closeInteractivePopup();
    });
    print("Cargando datos para heatmap de Firebase...");

    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Reportes')
          .where('fechaCreacion',
              isGreaterThan: Timestamp.fromDate(
                  DateTime.now().subtract(const Duration(days: 90))))
          .get();

      print("Reportes obtenidos de Firestore: ${snapshot.docs.length}");

      _heatmapReportData.clear();
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['ubicacion'] != null &&
            data['ubicacion']['latitud'] is double &&
            data['ubicacion']['longitud'] is double &&
            data['nivelRiesgo'] is String) {
          _heatmapReportData.add({
            'lat': data['ubicacion']['latitud'] as double,
            'lng': data['ubicacion']['longitud'] as double,
            'riskLevel': data['nivelRiesgo'] as String,
          });
        } else {
          print(
              "Documento con datos incompletos o tipo incorrecto: ${doc.id}");
        }
      }
      print("Reportes procesados para heatmap: ${_heatmapReportData.length}");
      _generateAndDisplayHeatmapVisuals(); 
    } catch (e) {
      print("Error cargando datos para heatmap de Firebase: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Error al cargar datos del mapa de calor: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHeatmapData = false;
        });
      }
    }
  }

  // Genera los cuadrados base y los círculos de reportes para el modo heatmap
  void _generateAndDisplayHeatmapVisuals() {
    Set<Polygon> collectedPolygons = {}; 
    Set<Circle> collectedReportCircles = {}; 

    print(
        "Generando visuales para heatmap. Cantidad de reportes: ${_heatmapReportData.length}");

    final double minLat = -18.087; 
    final double maxLat = -17.977; 
    final double minLng = -70.321; 
    final double maxLng = -70.197; 
    final int gridDivisions = 10; 
    final double latStep = (maxLat - minLat) / gridDivisions;
    final double lngStep = (maxLng - minLng) / gridDivisions;
    
    final double halfSideLat = latStep / 2.0;
    final double halfSideLng = lngStep / 2.0;
    final Color safeFillColor = Colors.green.withAlpha(30); 

    for (int i = 0; i <= gridDivisions; i++) {
      for (int j = 0; j <= gridDivisions; j++) {
        double centerLat = minLat + (i * latStep);
        double centerLng = minLng + (j * lngStep);

        List<LatLng> points = [
          LatLng(centerLat - halfSideLat, centerLng - halfSideLng),
          LatLng(centerLat + halfSideLat, centerLng - halfSideLng),
          LatLng(centerLat + halfSideLat, centerLng + halfSideLng),
          LatLng(centerLat - halfSideLat, centerLng + halfSideLng),
        ];

        collectedPolygons.add(
          Polygon(
            polygonId: PolygonId('safe_base_square_${i}_$j'),
            points: points,
            fillColor: safeFillColor,
            strokeColor: Colors.transparent,
            strokeWidth: 0,
            consumeTapEvents: false, 
          ),
        );
      }
    }
    print(
        ">>> [DEBUG] Heatmap: Añadidos ${collectedPolygons.length} polígonos base 'Seguro'");

    for (var reporte in _heatmapReportData) {
      Color reportCircleFillColor;
      double reportRadius = 150; 
      int reportAlpha = 100;    

      String currentRiskLevel =
          (reporte['riskLevel'] as String?)?.trim() ?? 'Desconocido';

      switch (currentRiskLevel) {
        case 'Alto': 
        case 'Alto riesgo':
          reportCircleFillColor = Colors.red.withAlpha(reportAlpha);
          break;
        case 'Medio':
        case 'Riesgo moderado':
          reportCircleFillColor = Colors.orange.withAlpha(reportAlpha);
          break;
        case 'Bajo':
        case 'Poco riesgo':
          reportCircleFillColor = Colors.yellow.withAlpha(reportAlpha);
          break;
        default:
          reportCircleFillColor = Colors.blueGrey.withAlpha(
              reportAlpha - 20 > 0 ? reportAlpha - 20 : reportAlpha);
          reportRadius = 50; 
      }

      collectedReportCircles.add(
        Circle(
          circleId: CircleId(
              'reporte_${reporte['lat']}_${reporte['lng']}_${DateTime.now().millisecondsSinceEpoch}_${collectedReportCircles.length}'),
          center: LatLng(reporte['lat'], reporte['lng']),
          radius: reportRadius,
          fillColor: reportCircleFillColor,
          strokeColor: reportCircleFillColor.withAlpha(
              reportAlpha + 50 > 255 ? 255 : reportAlpha + 50), 
          strokeWidth: 0,
        ),
      );
    }

    if (mounted) {
      print(
          ">>> [DEBUG] Heatmap: Preparando para actualizar ${collectedPolygons.length} polígonos y ${collectedReportCircles.length} círculos en el estado.");
      setState(() {
        polygons = Set<Polygon>.from(collectedPolygons);
        circles = Set<Circle>.from(collectedReportCircles);
      });
      print(
          ">>> [DEBUG] Heatmap: Estado actualizado. 'polygons' tiene ${polygons.length}, 'circles' tiene ${circles.length} elementos.");
    }
  }

  Future<void> _animateToCurrentUserLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      // Podrías mostrar un SnackBar o diálogo aquí si lo deseas
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied, we cannot request permissions.');
      return;
    } 

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15.0, // O el nivel de zoom que prefieras
          ),
        ),
      );
    } catch (e) {
      print("Error obteniendo la ubicación actual: $e");
    }
  }

  void _toggleMapMode() {
    setState(() {
      if (_currentMapMode == MapDisplayMode.interactiveTap) {
        _currentMapMode = MapDisplayMode.heatmapFromFirebase;
        if (isPopupInteractiveVisible) _closeInteractivePopup();
        circles.clear();
        polygons.clear();
        riskLevelInteractive = null;
        _loadAndDisplayHeatmapData().then((_) {
          _animateToCurrentUserLocation();
        });
      } else {
        _currentMapMode = MapDisplayMode.interactiveTap;
        circles.clear();
        polygons.clear();
        if (isPopupInteractiveVisible) _closeInteractivePopup();
      }
    });
  }

  void _toggleLeyenda() {
    setState(() {
      isLeyendaVisible = !isLeyendaVisible;
    });
  }

  void _closeLeyenda() {
    setState(() {
      isLeyendaVisible = false;
    });
  }

  void _handleLogout() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    Color riskColorInteractivePopup = Colors.green;
    if (riskLevelInteractive == 'Peligroso') {
      riskColorInteractivePopup = Colors.red;
    } else if (riskLevelInteractive == 'Medio') {
      riskColorInteractivePopup = Colors.orange;
    }

    return Scaffold(
      drawer: BarraLateral(onLogout: _handleLogout),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kInitialPosition,
            zoomControlsEnabled: false,
            zoomGesturesEnabled: true,
            myLocationButtonEnabled: false,
            myLocationEnabled: true, 
            circles: circles, 
            polygons: polygons, 
            onTap: _onMapTap,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
          ),
          Positioned(
            top: 40,
            left: 20,
            child: SafeArea(
              child: Builder(
                builder: (context) => Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(217),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
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
                  color: Colors.white.withAlpha(217),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
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
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(217),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(_currentMapMode == MapDisplayMode.interactiveTap
                      ? Icons.thermostat_outlined 
                      : Icons.touch_app_outlined), 
                  color: Colors.black54,
                  tooltip: _currentMapMode == MapDisplayMode.interactiveTap
                      ? 'Ver Mapa de Calor (Reportes)'
                      : 'Ver Mapa Interactivo (Toque)',
                  onPressed: _toggleMapMode,
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _buttonAnimation,
            builder: (context, child) {
              final double zoomBottomPosition = isPopupInteractiveVisible
                  ? 240 + (_buttonAnimation.value * 60)
                  : 120 + ((1 - _buttonAnimation.value) * 40);
              return Positioned(
                bottom: zoomBottomPosition,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          _mapController?.animateCamera(CameraUpdate.zoomIn());
                        },
                        tooltip: 'Zoom in',
                      ),
                      const Divider(height: 1, indent: 4, endIndent: 4),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          _mapController
                              ?.animateCamera(CameraUpdate.zoomOut());
                        },
                        tooltip: 'Zoom out',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_currentMapMode == MapDisplayMode.interactiveTap &&
              isPopupInteractiveVisible &&
              riskLevelInteractive != null)
            Positioned(
              bottom: 20,
              left: 10,
              right: 10,
              child: SlideTransition(
                position: _slideAnimation,
                child: Card(
                  elevation: 8,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Tipo de Peligro: ${dangerTypeInteractive ?? '-'}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: riskColorInteractivePopup,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Nivel de Riesgo: ${riskLevelInteractive!}',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: riskColorInteractivePopup),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                                'Última Actualización: ${lastUpdatedInteractive ?? '-'}',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black54)),
                            const SizedBox(height: 8),
                            const Text('Recomendaciones:',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87)),
                            const SizedBox(height: 4),
                            Text(safetyRecommendationsInteractive ?? '-',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.black54)),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                            ),
                            onTap: _closeInteractivePopup,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                ),
                              ),
                              child: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          AnimatedBuilder(
            animation: _buttonAnimation,
            builder: (context, child) {
              final double bottomPosition = isPopupInteractiveVisible
                  ? 190 + (_buttonAnimation.value * 40)
                  : 20 + ((1 - _buttonAnimation.value) * 40);
              return Positioned(
                bottom: bottomPosition,
                right: 20,
                child: child!,
              );
            },
            child: const EmergencyButton(),
          ),
          if (isLeyendaVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeLeyenda,
                child: Container(
                  color: Colors.black.withAlpha(128),
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
                                  MediaQuery.of(context).size.height * 0.9,
                            ),
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
          if (_isLoadingHeatmapData)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
