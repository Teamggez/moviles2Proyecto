import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'widgets/botonEmergencia.dart';
import 'widgets/barralateral.dart';
import 'widgets/LeyendaMapa.dart';
import 'screenRutaSegura.dart';

class ScreenPrincipal extends StatefulWidget {
  const ScreenPrincipal({super.key});

  @override
  State<ScreenPrincipal> createState() => _ScreenPrincipalState();
}

class _ScreenPrincipalState extends State<ScreenPrincipal> with SingleTickerProviderStateMixin {
  String? dangerType;
  String? riskLevel;
  String? lastUpdated;
  String? safetyRecommendations;
  bool isPopupVisible = false;
  bool isLeyendaVisible = false;

  LatLng? tapPosition;
  Set<Circle> circles = {};

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
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack)
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(-18.0146, -70.2534),
    zoom: 13.0,
  );

  void _onMapTap(LatLng position) {
    if (isLeyendaVisible) {
      setState(() {
        isLeyendaVisible = false;
      });
      return;
    }

    setState(() {
      tapPosition = position;
      dangerType = 'Robo';
      lastUpdated = '2025-05-02 ${DateTime.now().hour}:${DateTime.now().minute}';
      safetyRecommendations = 'Cuidado con tus pertenencias en esta zona.';

      double lat = position.latitude;
      double lng = position.longitude;

      if (lat > -18.01 && lat < -17.99) {
        riskLevel = 'Peligroso';
      } else if (lng > -70.26 && lng < -70.24) {
        riskLevel = 'Medio';
      } else {
        riskLevel = 'Seguro';
      }

      _addCircle(position);
      isPopupVisible = true;
      _animationController.forward(from: 0.0);
    });
  }

  void _addCircle(LatLng position) {
    Color circleColor = Colors.green.withAlpha(153); // Replaced withOpacity(0.6)
    double circleRadius = 60.0;

    if (riskLevel == 'Peligroso') {
      circleColor = Colors.red.withAlpha(153); // Replaced withOpacity(0.6)
      circleRadius = 80.0;
    } else if (riskLevel == 'Medio') {
      circleColor = Colors.orange.withAlpha(153); // Replaced withOpacity(0.6)
      circleRadius = 70.0;
    }

    Circle circle = Circle(
      circleId: CircleId(position.toString()),
      center: position,
      radius: circleRadius,
      fillColor: circleColor,
      strokeColor: circleColor.withAlpha(204), // Replaced withOpacity(0.8)
      strokeWidth: 2,
    );

    circles.clear();
    circles.add(circle);
  }

  void _closePopup() {
    _animationController.reverse().then((_) {
      if (mounted) { // Check if widget is still mounted
        setState(() {
          isPopupVisible = false;
        });
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
    // final mediaQuery = MediaQuery.of(context); // Removed unused mediaQuery
    // final screenHeight = mediaQuery.size.height; // Removed unused screenHeight

    Color riskColor = Colors.green;
    if (riskLevel == 'Peligroso') {
      riskColor = Colors.red;
    } else if (riskLevel == 'Medio') {
      riskColor = Colors.orange;
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
                    color: Colors.white.withAlpha(217), // Replaced withOpacity(0.85)
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(51), // Replaced withOpacity(0.2)
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
                  color: Colors.white.withAlpha(217), // Replaced withOpacity(0.85)
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(51), // Replaced withOpacity(0.2)
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
          AnimatedBuilder(
            animation: _buttonAnimation,
            builder: (context, child) {
              final double zoomBottomPosition = isPopupVisible
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
                        color: Colors.black.withAlpha(51), // Replaced withOpacity(0.2)
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // Ensure column takes minimum space
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          _mapController?.animateCamera(
                            CameraUpdate.zoomIn(),
                          );
                        },
                        tooltip: 'Zoom in',
                      ),
                      const Divider(height: 1, indent: 4, endIndent: 4), // Added indent
                      IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          _mapController?.animateCamera(
                            CameraUpdate.zoomOut(),
                          );
                        },
                        tooltip: 'Zoom out',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (isPopupVisible && riskLevel != null)
            Positioned(
              bottom: 20,
              left: 10,
              right: 10,
              child: SlideTransition(
                position: _slideAnimation,
                child: Card(
                  elevation: 8,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                              'Tipo de Peligro: ${dangerType ?? '-'}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: riskColor,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Nivel de Riesgo: ${riskLevel!}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: riskColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Última Actualización: ${lastUpdated ?? '-'}',
                              style: const TextStyle(fontSize: 16, color: Colors.black54)
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Recomendaciones:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)
                            ),
                            const SizedBox(height: 4),
                            Text(
                              safetyRecommendations ?? '-', // Removed unnecessary interpolation
                              style: const TextStyle(fontSize: 16, color: Colors.black54)
                            ),
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
                            onTap: _closePopup,
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
            Positioned(
              bottom: 100,
              left: 20,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.directions),
                label: const Text("Ruta Segura"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ScreenRutaSegura()),
                  );
                },
              ),
            ),
            
          AnimatedBuilder(
            animation: _buttonAnimation,
            builder: (context, child) {
              final double bottomPosition = isPopupVisible
                  ? 190 + (_buttonAnimation.value * 40)
                  : 20 + ((1 - _buttonAnimation.value) * 40);

              return Positioned(
                bottom: bottomPosition,
                right: 20,
                child: child!, // Pass the child (EmergencyButton)
              );
            },
            child: const EmergencyButton(), // Added const and moved here
          ),
          if (isLeyendaVisible)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeLeyenda,
                child: Container(
                  color: Colors.black.withAlpha(128), // Replaced withOpacity(0.5)
                  child: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        child: GestureDetector(
                          onTap: () {},
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.9,
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
        ],
      ),
    );
  }
}
