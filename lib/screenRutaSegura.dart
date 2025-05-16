import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart' as g_places;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importar Firestore

// TODO: DE  GOOGLE CLOUD
// ASEGÚRARSE DE QUE ESTÉ HABILITADA PARA:
// - Places API
// - Directions API (Legacy, o migra a Routes API)
// - Geocoding API
// - Maps SDK for Android/iOS
const String GOOGLE_MAPS_API_KEY = 'AIzaSyBl1LlKDZ_TslvGooMeecMRl6vrXH3cDRs';

class ScreenRutaSegura extends StatefulWidget {
  const ScreenRutaSegura({super.key});

  @override
  State<ScreenRutaSegura> createState() => _ScreenRutaSeguraState();
}

// Estructura para el caché de rutas
class PolylineData {
  final List<LatLng> coordinates;
  final Color color;
  final String polylineId;
  final double zIndex;

  PolylineData({
    required this.coordinates,
    required this.color,
    required this.polylineId,
    required this.zIndex,
  });
}

// Enum para tipos de ruta
enum RouteType { normal, avoidingReports }

class _ScreenRutaSeguraState extends State<ScreenRutaSegura> {
  GoogleMapController? _mapController;
  final TextEditingController origenController = TextEditingController();
  final TextEditingController destinoController = TextEditingController();

  final _places = g_places.GoogleMapsPlaces(apiKey: GOOGLE_MAPS_API_KEY);

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(-18.0146, -70.2534), // Tacna, Peru
    zoom: 13.0,
  );

  Set<Polyline> _polylines = {};
  List<g_places.Prediction> _placeSuggestions = [];
  bool _isFetchingSuggestions = false;
  bool _isOriginFieldFocused = false;

  Set<Marker> _markers = {}; // Para origen, destino y reportes

  LatLng? _origenLatLng;
  LatLng? _destinoLatLng;

  // --- Variables para reportes y caché ---
  List<Map<String, dynamic>> _reportesActivosRiesgosos = [];
  final Map<String, PolylineData> _routeCache = {};
  final String _normalRouteId = 'ruta_normal';
  final String _avoidingRouteId = 'ruta_evitando_reportes';
  // ---

  @override
  void initState() {
    super.initState();
    print("[INIT] Estado inicializado.");
    _preguntarUsoUbicacionActual();
    _fetchReportesRelevantes();
  }

  Future<void> _fetchReportesRelevantes() async {
    print("[FIREBASE] Iniciando carga de reportes relevantes...");
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Reportes')
          .where('estado', isEqualTo: 'Activo')
          .where('nivelRiesgo',
              isEqualTo: 'Bajo') // Filtrar por alto riesgo
          .get();

      if (mounted) {
        setState(() {
          _reportesActivosRiesgosos = snapshot.docs
              .map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                data['docId'] =
                    doc.id; // Guardar el ID del documento por si se necesita
                return data;
              })
              .where((reporte) =>
                  reporte['ubicacion'] != null &&
                  reporte['ubicacion']['latitud']
                      is num && // Asegurar que son números
                  reporte['ubicacion']['longitud'] is num)
              .toList();
          _updateReportMarkers(); // Actualizar marcadores de reportes en el mapa
        });
        print(
            "[FIREBASE] Reportes activos y riesgosos cargados: ${_reportesActivosRiesgosos.length}");
        _reportesActivosRiesgosos.forEach((r) {
          print(
              "  - Reporte: ${r['titulo']} (Lat: ${r['ubicacion']['latitud']}, Lng: ${r['ubicacion']['longitud']})");
        });
      }
    } catch (e) {
      print("[FIREBASE_ERROR] Error al obtener reportes: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar reportes: $e')),
        );
      }
    }
  }

  void _updateReportMarkers() {
    if (!mounted) return;
    Set<Marker> newReportMarkers = {};
    for (var reporte in _reportesActivosRiesgosos) {
      final ubicacion = reporte['ubicacion'];
      final LatLng pos = LatLng(
          ubicacion['latitud'].toDouble(), ubicacion['longitud'].toDouble());
      newReportMarkers.add(Marker(
        markerId: MarkerId('reporte_${reporte['docId']}'),
        position: pos,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: "Reporte: ${reporte['titulo'] ?? 'Sin título'}",
          snippet:
              "${reporte['descripcion'] ?? ''} - ${reporte['nivelRiesgo']}",
        ),
      ));
    }
    // Mantener marcadores de origen y destino, reemplazar solo los de reportes
    _markers.removeWhere((m) => m.markerId.value.startsWith('reporte_'));
    _markers.addAll(newReportMarkers);
    setState(() {}); // Para refrescar el mapa con los nuevos marcadores
    print(
        "[MAP] Marcadores de reportes actualizados: ${newReportMarkers.length}");
  }

  Future<void> _preguntarUsoUbicacionActual() async {
    // ... (código existente sin cambios)
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    bool? usarUbicacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usar ubicación actual'),
        content: const Text(
            '¿Deseas usar tu ubicación actual como punto de origen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí')),
        ],
      ),
    );

    if (usarUbicacion == true) {
      await _usarUbicacionActualComoOrigen();
    }
  }

  Future<String> _getAddressFromLatLng(LatLng latLng) async {
    // ... (código existente sin cambios)
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = "";
        if (place.street != null && place.street!.isNotEmpty)
          address += "${place.street}, ";
        if (place.locality != null && place.locality!.isNotEmpty)
          address += "${place.locality}, ";
        if (place.subAdministrativeArea != null &&
            place.subAdministrativeArea!.isNotEmpty)
          address += "${place.subAdministrativeArea}, ";
        if (place.country != null && place.country!.isNotEmpty)
          address += place.country!;

        address = address.trim();
        if (address.endsWith(','))
          address = address.substring(0, address.length - 1);

        if (address.isEmpty && place.name != null) return place.name!;
        return address.isNotEmpty
            ? address
            : "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
      }
    } catch (e) {
      print("[GEOCODING_ERROR] Error obteniendo dirección de LatLng: $e");
    }
    return "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
  }

  Future<void> _usarUbicacionActualComoOrigen() async {
    // ... (código existente, asegurándose de llamar a _clearAllPolylines y limpiar _routeCache)
    print("[LOCATION] Usando ubicación actual como origen...");
    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!servicioHabilitado) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Por favor habilita el servicio de ubicación.')));
      return;
    }

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permiso de ubicación denegado.')));
        return;
      }
    }
    if (permiso == LocationPermission.deniedForever && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permiso de ubicación denegado permanentemente.')));
      return;
    }

    try {
      Position posicion = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final origenLatLng = LatLng(posicion.latitude, posicion.longitude);
      String direccion = await _getAddressFromLatLng(origenLatLng);

      if (mounted) {
        setState(() {
          origenController.text = direccion;
          _origenLatLng = origenLatLng;
          _updateMarker('origen', origenLatLng, "Origen: Actual",
              BitmapDescriptor.hueBlue);
          _clearAllPolylinesAndCache();
        });
        _mapController
            ?.animateCamera(CameraUpdate.newLatLngZoom(origenLatLng, 15));
        print(
            "[LOCATION] Origen fijado en ubicación actual: $direccion ($origenLatLng)");
      }
    } catch (e) {
      print("[LOCATION_ERROR] Error al obtener ubicación: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al obtener ubicación: $e')));
        setState(() {
          origenController.clear();
          _origenLatLng = null;
          _markers.removeWhere((m) => m.markerId == const MarkerId('origen'));
          _clearAllPolylinesAndCache();
        });
      }
    }
  }

  Future<void> _getPlaceSuggestions(String query,
      {bool forOrigin = false}) async {
    // ... (código existente sin cambios)
    if (query.isEmpty) {
      if (mounted) setState(() => _placeSuggestions = []);
      return;
    }
    if (_isFetchingSuggestions) return;

    if (mounted) setState(() => _isFetchingSuggestions = true);

    g_places.Location? locationBias = _origenLatLng != null
        ? g_places.Location(
            lat: _origenLatLng!.latitude, lng: _origenLatLng!.longitude)
        : g_places.Location(
            lat: _kInitialPosition.target.latitude,
            lng: _kInitialPosition.target.longitude);

    final response = await _places.autocomplete(query,
        location: locationBias,
        radius: 50000,
        language: 'es',
        components: [g_places.Component("country", "pe")]);

    if (mounted) {
      if (response.isOkay) {
        setState(() => _placeSuggestions = response.predictions);
      } else {
        print("[PLACES_API_ERROR] Autocomplete: ${response.errorMessage}");
        setState(() => _placeSuggestions = []);
      }
      setState(() => _isFetchingSuggestions = false);
    }
  }

  Future<void> _getPlaceDetailsAndSet(g_places.Prediction suggestion,
      {required bool isOrigin}) async {
    // ... (código existente, asegurándose de llamar a _clearAllPolylines y limpiar _routeCache)
    if (suggestion.placeId == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No se pudo obtener detalles del lugar.')));
      return;
    }

    final detailsResponse =
        await _places.getDetailsByPlaceId(suggestion.placeId!);
    if (mounted) {
      if (detailsResponse.isOkay && detailsResponse.result.geometry != null) {
        final lat = detailsResponse.result.geometry!.location.lat;
        final lng = detailsResponse.result.geometry!.location.lng;
        final placeLatLng = LatLng(lat, lng);
        String placeDescription = suggestion.description ?? "$lat, $lng";

        setState(() {
          _placeSuggestions.clear();
          if (isOrigin) {
            origenController.text = placeDescription;
            _origenLatLng = placeLatLng;
            _updateMarker(
                'origen',
                placeLatLng,
                "Origen: ${suggestion.structuredFormatting?.mainText ?? ''}",
                BitmapDescriptor.hueBlue);
            print(
                "[PLACES] Origen seleccionado de sugerencia: $placeDescription ($placeLatLng)");
          } else {
            destinoController.text = placeDescription;
            _destinoLatLng = placeLatLng;
            _updateMarker(
                'destino',
                placeLatLng,
                "Destino: ${suggestion.structuredFormatting?.mainText ?? ''}",
                BitmapDescriptor.hueRed);
            print(
                "[PLACES] Destino seleccionado de sugerencia: $placeDescription ($placeLatLng)");
          }
          _clearAllPolylinesAndCache();
        });
        _mapController
            ?.animateCamera(CameraUpdate.newLatLngZoom(placeLatLng, 15));
      } else {
        print("[PLACES_API_ERROR] GetDetails: ${detailsResponse.errorMessage}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Error al obtener detalles: ${detailsResponse.errorMessage}')));
      }
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    // ... (código existente sin cambios)
    if (address.isEmpty) return null;
    print("[GEOCODING] Intentando geocodificar: $address");
    try {
      final response = await _places.searchByText(address,
          location: g_places.Location(
              lat: _kInitialPosition.target.latitude,
              lng: _kInitialPosition.target.longitude),
          radius: 50000,
          language: 'es',
          region: 'pe');
      if (response.isOkay && response.results.isNotEmpty) {
        final geom = response.results.first.geometry;
        if (geom != null) {
          print(
              "[GEOCODING] Éxito con Places API: ${geom.location.lat}, ${geom.location.lng}");
          return LatLng(geom.location.lat, geom.location.lng);
        }
      }
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        print(
            "[GEOCODING] Éxito con Geocoding Package: ${locations.first.latitude}, ${locations.first.longitude}");
        return LatLng(locations.first.latitude, locations.first.longitude);
      }
    } catch (e) {
      print("[GEOCODING_ERROR] Error geocodificando '$address': $e");
    }
    print("[GEOCODING] Falló para: $address");
    return null;
  }

  void _updateMarker(String id, LatLng position, String title, double hue) {
    if (!mounted) return;
    final marker = Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(title: title),
      icon: BitmapDescriptor.defaultMarkerWithHue(hue),
    );
    setState(() {
      _markers.removeWhere((m) => m.markerId == MarkerId(id));
      _markers.add(marker);
    });
  }

  void _clearAllPolylinesAndCache() {
    if (mounted) {
      setState(() {
        _polylines.clear();
      });
      _routeCache.clear();
      print("[ROUTE] Polilíneas y caché de rutas limpiados.");
    }
  }

  Future<void> _handleMapTap(LatLng tappedPoint) async {
    // ... (código existente, asegurándose de llamar a _clearAllPolylines y limpiar _routeCache)
    if (!mounted) return;
    print("[MAP_TAP] Punto tocado: $tappedPoint");

    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Seleccionar Punto'),
        content:
            const Text('¿Deseas establecer este punto como origen o destino?'),
        actions: <Widget>[
          TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(null)),
          TextButton(
              child: const Text('Origen', style: TextStyle(color: Colors.blue)),
              onPressed: () => Navigator.of(context).pop('origen')),
          TextButton(
              child: const Text('Destino', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop('destino')),
        ],
      ),
    );

    if (choice == null || !mounted) {
      print("[MAP_TAP] Selección cancelada.");
      return;
    }

    String address = await _getAddressFromLatLng(tappedPoint);

    setState(() {
      _clearAllPolylinesAndCache();
      if (choice == 'origen') {
        origenController.text = address;
        _origenLatLng = tappedPoint;
        _updateMarker(
            'origen', tappedPoint, "Origen: Mapa", BitmapDescriptor.hueBlue);
        print("[MAP_TAP] Origen fijado desde mapa: $address ($tappedPoint)");
      } else if (choice == 'destino') {
        destinoController.text = address;
        _destinoLatLng = tappedPoint;
        _updateMarker(
            'destino', tappedPoint, "Destino: Mapa", BitmapDescriptor.hueRed);
        print("[MAP_TAP] Destino fijado desde mapa: $address ($tappedPoint)");
      }
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(tappedPoint));
  }

  Future<void> _getAndDisplayRoute({
    required LatLng origin,
    required LatLng destination,
    required RouteType routeType,
    // List<LatLng> waypointsToAvoidAround = const [], // Para la lógica de evitación avanzada
  }) async {
    String routeTypeStr = routeType.toString().split('.').last;
    String polylineIdStr =
        routeType == RouteType.normal ? _normalRouteId : _avoidingRouteId;
    Color routeColor =
        routeType == RouteType.normal ? Colors.blueAccent : Colors.orangeAccent;
    double routeZIndex = routeType == RouteType.normal ? 1 : 2;

    // String waypointsHash = waypointsToAvoidAround.map((p) => '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}').join('|');
    // Clave de caché simplificada por ahora, ya que la evitación real no está implementada con waypoints de desvío
    String cacheKey = "${origin.latitude},${origin.longitude}_"
        "${destination.latitude},${destination.longitude}_"
        "$routeTypeStr";

    if (_routeCache.containsKey(cacheKey)) {
      print("[ROUTE_CACHE] Ruta $routeTypeStr encontrada en caché: $cacheKey");
      final cachedData = _routeCache[cacheKey]!;
      if (mounted) {
        setState(() {
          _polylines.removeWhere(
              (p) => p.polylineId == PolylineId(cachedData.polylineId));
          _polylines.add(Polyline(
            polylineId: PolylineId(cachedData.polylineId),
            points: cachedData.coordinates,
            color: cachedData.color,
            width: 6,
            zIndex: cachedData.zIndex.toInt(),
          ));
        });
      }
      return;
    }

    print("[ROUTE_API] Solicitando ruta $routeTypeStr desde API...");
    print("           Origen: $origin, Destino: $destination");

    String urlParams =
        'origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}';

    // Aquí iría la lógica para añadir waypoints de desvío si routeType es avoidingReports
    // y se ha implementado el cálculo de dichos waypoints.
    // Por ahora, la URL es la misma para ambas, confiando en `alternatives=true` si se usa.
    // String waypointsForApi = "";
    // if (routeType == RouteType.avoidingReports && waypointsToAvoidAround.isNotEmpty) {
    //   // Lógica para construir el string de waypoints para la API
    //   // waypointsForApi = "&waypoints=optimize:true|" + waypointsToAvoidAround.map((p) => "${p.latitude},${p.longitude}").join('|');
    // }

    String url =
        'https://maps.googleapis.com/maps/api/directions/json?$urlParams&mode=driving&language=es&key=$GOOGLE_MAPS_API_KEY';
    // Para obtener alternativas y elegir la que no pase por reportes:
    // '&alternatives=true';

    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          // Si se usa alternatives=true, data['routes'] puede tener varias.
          // Aquí tomamos la primera (índice 0) para la ruta "normal"
          // y si hay una segunda (índice 1) la podríamos usar para "avoidingReports".
          // Esto es una simplificación.
          int routeIndex = 0;
          // if (routeType == RouteType.avoidingReports && data['routes'].length > 1) {
          //   routeIndex = 1; // Tomar la segunda ruta como alternativa si existe
          // } else if (routeType == RouteType.avoidingReports && data['routes'].length <= 1) {
          //   print("[ROUTE_API] No se encontró una ruta alternativa para $routeTypeStr. Usando la ruta principal.");
          // }

          final apiRoute = data['routes'][routeIndex];
          List<dynamic> steps = apiRoute['legs'][0]['steps'];
          List<LatLng> routeCoordinates = [];
          for (var step in steps) {
            routeCoordinates
                .addAll(_decodePolyline(step['polyline']['points']));
          }

          if (routeCoordinates.isEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content:
                    Text('No se pudo decodificar la ruta $routeTypeStr.')));
            return;
          }
          print(
              "[ROUTE_API] Ruta $routeTypeStr decodificada con ${routeCoordinates.length} puntos.");

          final polylineData = PolylineData(
            coordinates: routeCoordinates,
            color: routeColor,
            polylineId: polylineIdStr,
            zIndex: routeZIndex,
          );
          _routeCache[cacheKey] = polylineData;

          if (mounted) {
            setState(() {
              _polylines.removeWhere(
                  (p) => p.polylineId == PolylineId(polylineIdStr));
              _polylines.add(Polyline(
                polylineId: PolylineId(polylineIdStr),
                points: routeCoordinates,
                color: routeColor,
                width: 6,
                zIndex: routeZIndex.toInt(),
              ));
            });
            // Solo animar cámara para la primera ruta que se muestra
            if (_polylines.length == 1) {
              _mapController?.animateCamera(CameraUpdate.newLatLngBounds(
                  _boundsFromLatLngList(routeCoordinates), 70));
            }
          }
        } else {
          print(
              "[DIRECTIONS_API_ERROR] ($routeTypeStr): ${data['status']} - ${data['error_message']}");
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    'No se encontró ruta $routeTypeStr: ${data['status']} ${data['error_message'] ?? ''}')));
        }
      } else {
        print(
            "[HTTP_ERROR] ($routeTypeStr): ${response.statusCode} - ${response.body}");
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  'Error al obtener ruta $routeTypeStr: ${response.statusCode}')));
      }
    } catch (e) {
      print("[EXCEPTION] ($routeTypeStr): $e");
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ocurrió un error ($routeTypeStr): $e')));
    }
  }

  Future<void> _showAllRoutes() async {
    print("[UI_ACTION] Botón 'Mostrar Rutas' presionado.");
    // Validar origen y destino
    if (_origenLatLng == null && origenController.text.isNotEmpty) {
      final geocodedOrigin = await _geocodeAddress(origenController.text);
      if (geocodedOrigin != null && mounted)
        setState(() => _origenLatLng = geocodedOrigin);
      else {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Origen no válido.')));
        return;
      }
    }
    if (_destinoLatLng == null && destinoController.text.isNotEmpty) {
      final geocodedDestino = await _geocodeAddress(destinoController.text);
      if (geocodedDestino != null && mounted)
        setState(() => _destinoLatLng = geocodedDestino);
      else {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Destino no válido.')));
        return;
      }
    }
    if (_origenLatLng == null || _destinoLatLng == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selecciona origen y destino.')));
      return;
    }

    _clearAllPolylinesAndCache(); // Limpiar polilíneas y caché antes de nuevas solicitudes

    // 1. Ruta Normal
    await _getAndDisplayRoute(
      origin: _origenLatLng!,
      destination: _destinoLatLng!,
      routeType: RouteType.normal,
    );

    // 2. Identificar reportes cercanos para la "ruta evitando reportes"
    List<Map<String, dynamic>> reportesConsideradosParaEvitar = [];
    if (_reportesActivosRiesgosos.isNotEmpty) {
      for (var reporte in _reportesActivosRiesgosos) {
        final ubicacion = reporte['ubicacion'];
        LatLng puntoReporte = LatLng(
            ubicacion['latitud'].toDouble(), ubicacion['longitud'].toDouble());
        if (_isReportNearRoute(_origenLatLng!, _destinoLatLng!, puntoReporte)) {
          reportesConsideradosParaEvitar.add(reporte);
        }
      }
    }

    if (reportesConsideradosParaEvitar.isNotEmpty) {
      print(
          "--- [AVOIDANCE_LOGIC] Intentando ruta conceptualmente 'evitando reportes'. ---");
      print(
          "Reportes considerados para evitación (cercanos a la ruta general):");
      for (var r in reportesConsideradosParaEvitar) {
        print(
            "  - Título: ${r['titulo']}, Coordenadas: Lat: ${r['ubicacion']['latitud']}, Lng: ${r['ubicacion']['longitud']}");
      }
      // Aquí es donde la lógica de evitación avanzada (cálculo de waypoints de desvío) iría.
      // Por ahora, solo solicitamos la ruta como si fuera una alternativa.
      await _getAndDisplayRoute(
        origin: _origenLatLng!,
        destination: _destinoLatLng!,
        routeType: RouteType.avoidingReports,
        // waypointsToAvoidAround: reportesConsideradosParaEvitar.map((r) => LatLng(r['ubicacion']['latitud'], r['ubicacion']['longitud'])).toList(),
      );
    } else {
      print(
          "[AVOIDANCE_LOGIC] No hay reportes activos y riesgosos relevantes para considerar evitación, o no se detectaron como cercanos.");
    }
  }

  bool _isReportNearRoute(
      LatLng origin, LatLng destination, LatLng reportPoint) {
    // Lógica muy simplificada: está dentro de un bounding box expandido.
    // Para una app real, considera usar `PolyUtil.isLocationOnPath` del SDK de Maps si tienes la ruta normal,
    // o una librería de geometría para calcular distancia de punto a segmento de línea.
    double minLat = origin.latitude < destination.latitude
        ? origin.latitude
        : destination.latitude;
    double maxLat = origin.latitude > destination.latitude
        ? origin.latitude
        : destination.latitude;
    double minLng = origin.longitude < destination.longitude
        ? origin.longitude
        : destination.longitude;
    double maxLng = origin.longitude > destination.longitude
        ? origin.longitude
        : destination.longitude;

    double padding = 0.05; // Ajusta este valor (grados decimales)
    bool isInBounds = reportPoint.latitude >= minLat - padding &&
        reportPoint.latitude <= maxLat + padding &&
        reportPoint.longitude >= minLng - padding &&
        reportPoint.longitude <= maxLng + padding;
    if (isInBounds) {
      print(
          "[AVOIDANCE_CHECK] Reporte en (${reportPoint.latitude}, ${reportPoint.longitude}) está DENTRO del bounding box general de la ruta.");
    } else {
      // print("[AVOIDANCE_CHECK] Reporte en (${reportPoint.latitude}, ${reportPoint.longitude}) está FUERA del bounding box general.");
    }
    return isInBounds;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    // ... (código existente sin cambios)
    assert(list.isNotEmpty);
    double minLat = list[0].latitude, maxLat = list[0].latitude;
    double minLng = list[0].longitude, maxLng = list[0].longitude;
    for (LatLng latLng in list) {
      if (latLng.latitude < minLat) minLat = latLng.latitude;
      if (latLng.latitude > maxLat) maxLat = latLng.latitude;
      if (latLng.longitude < minLng) minLng = latLng.longitude;
      if (latLng.longitude > maxLng) maxLng = latLng.longitude;
    }
    return LatLngBounds(
        southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  List<LatLng> _decodePolyline(String encoded) {
    // ... (código existente sin cambios)
    List<LatLng> points = [];
    int index = 0, len = encoded.length, lat = 0, lng = 0;
    while (index < len) {
      int shift = 0, result = 0, byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    print("[BUILD] Reconstruyendo widget principal.");
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ruta Segura"),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar reportes',
            onPressed: () {
              print("[UI_ACTION] Botón Recargar Reportes presionado.");
              _fetchReportesRelevantes();
            },
          )
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kInitialPosition,
            zoomControlsEnabled: true,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              print("[MAP] Mapa creado.");
            },
            onTap: _handleMapTap,
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- TextFormField Origen ---
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (mounted)
                          setState(() => _isOriginFieldFocused = hasFocus);
                        if (!hasFocus &&
                            origenController.text.isNotEmpty &&
                            _origenLatLng == null) {
                          _geocodeAddress(origenController.text).then((latLng) {
                            if (latLng != null && mounted) {
                              setState(() {
                                _origenLatLng = latLng;
                                _updateMarker(
                                    'origen',
                                    latLng,
                                    "Origen: ${origenController.text}",
                                    BitmapDescriptor.hueBlue);
                                _clearAllPolylinesAndCache();
                              });
                              _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(latLng, 15));
                            }
                          });
                        } else if (hasFocus && mounted) {
                          setState(() => _placeSuggestions.clear());
                        }
                      },
                      child: TextFormField(
                        controller: origenController,
                        decoration: InputDecoration(
                          hintText: 'Origen',
                          prefixIcon: const Icon(Icons.my_location),
                          suffixIcon: origenController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    if (mounted)
                                      setState(() {
                                        origenController.clear();
                                        _origenLatLng = null;
                                        _markers.removeWhere((m) =>
                                            m.markerId.value == 'origen');
                                        _placeSuggestions.clear();
                                        _clearAllPolylinesAndCache();
                                        print("[UI] Campo Origen limpiado.");
                                      });
                                  })
                              : null,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          if (_isOriginFieldFocused)
                            _getPlaceSuggestions(value, forOrigin: true);
                        },
                        onFieldSubmitted: (value) async {
                          if (value.isNotEmpty) {
                            FocusScope.of(context).unfocus();
                            final latLng = await _geocodeAddress(value);
                            if (latLng != null && mounted) {
                              setState(() {
                                _origenLatLng = latLng;
                                _updateMarker('origen', latLng,
                                    "Origen: $value", BitmapDescriptor.hueBlue);
                                _clearAllPolylinesAndCache();
                              });
                              _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(latLng, 15));
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'No se pudo encontrar origen.')));
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    // --- TextFormField Destino ---
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (mounted)
                          setState(() => _isOriginFieldFocused = !hasFocus);
                        if (!hasFocus &&
                            destinoController.text.isNotEmpty &&
                            _destinoLatLng == null) {
                          _geocodeAddress(destinoController.text)
                              .then((latLng) {
                            if (latLng != null && mounted) {
                              setState(() {
                                _destinoLatLng = latLng;
                                _updateMarker(
                                    'destino',
                                    latLng,
                                    "Destino: ${destinoController.text}",
                                    BitmapDescriptor.hueRed);
                                _clearAllPolylinesAndCache();
                              });
                              _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(latLng, 15));
                            }
                          });
                        } else if (hasFocus && mounted) {
                          setState(() => _placeSuggestions.clear());
                        }
                      },
                      child: TextFormField(
                        controller: destinoController,
                        decoration: InputDecoration(
                          hintText: 'Destino',
                          prefixIcon: const Icon(Icons.location_on),
                          suffixIcon: destinoController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    if (mounted)
                                      setState(() {
                                        destinoController.clear();
                                        _destinoLatLng = null;
                                        _markers.removeWhere((m) =>
                                            m.markerId.value == 'destino');
                                        _placeSuggestions.clear();
                                        _clearAllPolylinesAndCache();
                                        print("[UI] Campo Destino limpiado.");
                                      });
                                  })
                              : null,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          if (!_isOriginFieldFocused)
                            _getPlaceSuggestions(value, forOrigin: false);
                        },
                        onFieldSubmitted: (value) async {
                          if (value.isNotEmpty) {
                            FocusScope.of(context).unfocus();
                            final latLng = await _geocodeAddress(value);
                            if (latLng != null && mounted) {
                              setState(() {
                                _destinoLatLng = latLng;
                                _updateMarker('destino', latLng,
                                    "Destino: $value", BitmapDescriptor.hueRed);
                                _clearAllPolylinesAndCache();
                              });
                              _mapController?.animateCamera(
                                  CameraUpdate.newLatLngZoom(latLng, 15));
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'No se pudo encontrar destino.')));
                            }
                          }
                        },
                      ),
                    ),
                    if (_placeSuggestions.isNotEmpty) _buildSuggestionsList(),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.alt_route),
                      onPressed: _showAllRoutes,
                      label: const Text("Mostrar Rutas"),
                      style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.secondary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onSecondary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 30, vertical: 12),
                          textStyle: const TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    // ... (código existente sin cambios)
    return Material(
      elevation: 2,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2)),
          ],
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _placeSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = _placeSuggestions[index];
            return ListTile(
              leading: const Icon(Icons.location_pin, color: Colors.grey),
              title: Text(suggestion.structuredFormatting?.mainText ??
                  suggestion.description ??
                  ''),
              subtitle:
                  Text(suggestion.structuredFormatting?.secondaryText ?? ''),
              onTap: () {
                FocusScope.of(context).unfocus();
                _getPlaceDetailsAndSet(suggestion,
                    isOrigin: _isOriginFieldFocused);
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    print("[DISPOSE] Liberando controladores y listeners.");
    origenController.dispose();
    destinoController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
