import 'dart:convert';
import 'dart:typed_data'; 
import 'dart:ui' as ui; 
import 'dart:math'; 

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart' as g_places;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; 
import 'package:intl/date_symbol_data_local.dart';

// TODO:  DE GOOGLE CLOUD
const String GOOGLE_MAPS_API_KEY = 'AIzaSyBl1LlKDZ_TslvGooMeecMRl6vrXH3cDRs'; // ¡¡¡CAMBIAR!!!


enum TimeFilter { all, last24Hours, last12Hours, last1Hour }

String timeFilterToString(TimeFilter filter) {
  switch (filter) {
    case TimeFilter.all: return "Todos";
    case TimeFilter.last24Hours: return "Últimas 24h";
    case TimeFilter.last12Hours: return "Últimas 12h";
    case TimeFilter.last1Hour: return "Última 1h";
    default: return "Todos";
  }
}

class ScreenRutaSegura extends StatefulWidget {
  const ScreenRutaSegura({super.key});

  @override
  State<ScreenRutaSegura> createState() => _ScreenRutaSeguraState();
}

class PolylineData {
  final List<LatLng> coordinates;
  final Color color;
  final String polylineId;
  final double zIndex;
  final String? distanceText;
  final String? durationText;
  final bool isDetour;


  PolylineData({
    required this.coordinates,
    required this.color,
    required this.polylineId,
    required this.zIndex,
    this.distanceText,
    this.durationText,
    this.isDetour = false, 
  });
}

enum RouteType { normal, safe } 

class _ScreenRutaSeguraState extends State<ScreenRutaSegura> {
  GoogleMapController? _mapController;
  final TextEditingController origenController = TextEditingController();
  final TextEditingController destinoController = TextEditingController();

  final _places = g_places.GoogleMapsPlaces(apiKey: GOOGLE_MAPS_API_KEY);

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(-18.0146, -70.2534), zoom: 13.0,
  );

  Set<Polyline> _polylines = {};
  List<g_places.Prediction> _placeSuggestions = [];
  bool _isFetchingSuggestions = false;
  bool _isOriginFieldFocused = false;
  Set<Marker> _markers = {};

  LatLng? _origenLatLng;
  LatLng? _destinoLatLng;

  List<Map<String, dynamic>> _allActiveReports = [];
  List<Map<String, dynamic>> _filteredActiveReports = []; 
  final Map<String, PolylineData> _routeCache = {};
  final String _normalRouteId = 'ruta_normal';
  final String _safeRouteId = 'ruta_segura'; 

  final Map<String, BitmapDescriptor> _iconBitmapCache = {};
  BitmapDescriptor? _origenIcon; 

  TimeFilter _selectedTimeFilter = TimeFilter.all;

  final List<Map<String, dynamic>> _categories = [
    {'id': 'accident', 'name': 'Accidente', 'icon': Icons.car_crash, 'color': Colors.red},
    {'id': 'fire', 'name': 'Incendio', 'icon': Icons.local_fire_department, 'color': Colors.orange},
    {'id': 'roadblock', 'name': 'Vía bloqueada', 'icon': Icons.block, 'color': Colors.amber},
    {'id': 'protest', 'name': 'Manifestación', 'icon': Icons.people, 'color': Colors.yellow.shade700},
    {'id': 'theft', 'name': 'Robo', 'icon': Icons.money_off, 'color': Colors.purple},
    {'id': 'assault', 'name': 'Asalto', 'icon': Icons.personal_injury, 'color': Colors.deepPurple},
    {'id': 'violence', 'name': 'Violencia', 'icon': Icons.front_hand, 'color': Colors.red.shade800},
    {'id': 'vandalism', 'name': 'Vandalismo', 'icon': Icons.broken_image, 'color': Colors.indigo},
    {'id': 'others', 'name': 'Otros', 'icon': Icons.more_horiz, 'color': Colors.grey},
  ];

  String? _normalRouteInfo;
  String? _safeRouteInfo;
  
  // Constantes para la lógica de desvío (AJUSTAR ESTOS VALORES)
  static const double REPORT_INFLUENCE_RADIUS_METERS = 200.0; // Radio alrededor de un reporte para considerarlo "cerca" de la ruta
  static const double DETOUR_CALCULATION_RADIUS_DEGREES = 0.0025; // Radio para el centroide de la zona a evitar (aprox. 250-275m)
  static const double DETOUR_OFFSET_DEGREES = 0.0035;      // Distancia para desviar (aprox. 350-385m)


  Map<String, dynamic> _getCategoryStyle(String? typeId) { 
    final category = _categories.firstWhere((cat) => cat['id'] == typeId, orElse: () => _categories.firstWhere((cat) => cat['id'] == 'others'));
    return {'iconData': category['icon'], 'color': category['color'], 'name': category['name']};
  }
  Future<BitmapDescriptor> _bitmapDescriptorFromIconData(IconData iconData, Color color, {double size = 64.0, bool isOriginMarker = false}) async { 
    final String cacheKey = '${iconData.codePoint}_${color.value}_${size}_$isOriginMarker';
    if (_iconBitmapCache.containsKey(cacheKey)) return _iconBitmapCache[cacheKey]!;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final double iconSize = size * (isOriginMarker ? 0.7 : 0.6); 
    final double circleRadius = size / 2;
    if (isOriginMarker) {
      TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
      textPainter.text = TextSpan(text: String.fromCharCode(iconData.codePoint), style: TextStyle(fontSize: size * 0.8, fontFamily: iconData.fontFamily, package: iconData.fontPackage, color: color));
      textPainter.layout();
      textPainter.paint(canvas, Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2));
    } else {
      final Paint backgroundPaint = Paint()..color = color.withOpacity(0.25); 
      canvas.drawCircle(Offset(circleRadius, circleRadius), circleRadius, backgroundPaint);
      final Paint borderPaint = Paint()..color = color.withOpacity(0.8)..style = PaintingStyle.stroke..strokeWidth = 2.5; 
      canvas.drawCircle(Offset(circleRadius, circleRadius), circleRadius - 1.25, borderPaint); 
      TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
      textPainter.text = TextSpan(text: String.fromCharCode(iconData.codePoint), style: TextStyle(fontSize: iconSize, fontFamily: iconData.fontFamily, package: iconData.fontPackage, color: color));
      textPainter.layout();
      textPainter.paint(canvas, Offset((size - iconSize) / 2, (size - iconSize) / 2));
    }
    final ui.Image img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) { print("[ICON_ERROR] No se pudo convertir icono a ByteData."); return BitmapDescriptor.defaultMarker; }
    final Uint8List uint8List = byteData.buffer.asUint8List();
    final BitmapDescriptor descriptor = BitmapDescriptor.fromBytes(uint8List);
    _iconBitmapCache[cacheKey] = descriptor; 
    return descriptor;
  }

  @override
  void initState() { 
    super.initState();
    print("[INIT] Estado inicializado.");
    _prepareOriginIcon(); 
    initializeDateFormatting('es_ES', null).then((_) {
      print("[INIT] Datos localización 'es_ES' inicializados.");
      _preguntarUsoUbicacionActual();
      _fetchAllActiveReports();
    }).catchError((error) {
      print("[INIT_ERROR] Error inicializando localización: $error");
      _preguntarUsoUbicacionActual();
      _fetchAllActiveReports();
    });
  }
  Future<void> _prepareOriginIcon() async { 
    _origenIcon = await _bitmapDescriptorFromIconData(Icons.person_pin_circle, Colors.blue, size: 72.0, isOriginMarker: true);
    if (mounted) setState(() {});
  }
  Future<void> _fetchAllActiveReports() async { 
    print("[FIREBASE] Cargando TODOS reportes activos...");
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('Reportes').where('estado', isEqualTo: 'Activo').get();
      if (mounted) {
        _allActiveReports = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>; data['docId'] = doc.id; return data;
        }).where((r) => r['ubicacion'] != null && r['ubicacion']['latitud'] is num && r['ubicacion']['longitud'] is num).toList();
        _applyTimeFilterToReports(); 
        print("[FIREBASE] Reportes activos cargados: ${_allActiveReports.length}");
      }
    } catch (e) {
      print("[FIREBASE_ERROR] $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar reportes: $e')));
    }
  }
  void _applyTimeFilterToReports() { 
    if (!mounted) return;
    final now = DateTime.now(); Duration filterDuration;
    switch (_selectedTimeFilter) {
      case TimeFilter.last24Hours: filterDuration = const Duration(hours: 24); break;
      case TimeFilter.last12Hours: filterDuration = const Duration(hours: 12); break;
      case TimeFilter.last1Hour: filterDuration = const Duration(hours: 1); break;
      case TimeFilter.all: default:
         setState(() { _filteredActiveReports = List.from(_allActiveReports); });
        _updateReportMarkers(); 
        print("[FILTER] 'Todos'. Mostrando ${_filteredActiveReports.length} reportes."); return; 
    }
    final cutoffDate = now.subtract(filterDuration);
    setState(() {
      _filteredActiveReports = _allActiveReports.where((r) {
        dynamic fecha = r['fechaCreacion'];
        if (fecha is Timestamp) return fecha.toDate().isAfter(cutoffDate);
        if (fecha is String) { try { return DateTime.parse(fecha).isAfter(cutoffDate); } catch(e) { return false; }}
        return false; 
      }).toList();
    });
    print("[FILTER] '${timeFilterToString(_selectedTimeFilter)}'. Mostrando ${_filteredActiveReports.length} de ${_allActiveReports.length}.");
    _updateReportMarkers(); 
  }
  Future<void> _updateReportMarkers() async { 
    if (!mounted) return;
    Set<Marker> newReportMarkers = {};
    print("[MAP] Actualizando marcadores (${_filteredActiveReports.length} filtrados)...");
    for (var reporte in _filteredActiveReports) { 
      final ubicacion = reporte['ubicacion'];
      final LatLng pos = LatLng(ubicacion['latitud'].toDouble(), ubicacion['longitud'].toDouble());
      final String tipoReporte = reporte['tipo'] ?? 'others';
      final categoryStyle = _getCategoryStyle(tipoReporte);
      final BitmapDescriptor iconBitmap = await _bitmapDescriptorFromIconData(categoryStyle['iconData'], categoryStyle['color'], size: 56.0);
      newReportMarkers.add(Marker(
        markerId: MarkerId('reporte_${reporte['docId']}'), position: pos, icon: iconBitmap,
        onTap: () { print("[MARKER_TAP] Reporte: ${reporte['titulo']}"); _showReportDetailsModal(reporte); },
      ));
    }
    if (mounted) {
      setState(() {
        _markers.removeWhere((m) => m.markerId.value.startsWith('reporte_'));
        _markers.addAll(newReportMarkers);
      });
      print("[MAP] Marcadores de reportes actualizados: ${newReportMarkers.length}");
    }
  }
  void _showReportDetailsModal(Map<String, dynamic> reporte) { 
    final String tipoReporteId = reporte['tipo'] ?? 'others';
    final categoryStyle = _getCategoryStyle(tipoReporteId);
    final String imageUrl = (reporte['imagenes'] is List && (reporte['imagenes'] as List).isNotEmpty) ? (reporte['imagenes'] as List).first.toString() : '';
    String fechaFormateada = "No disponible";
    if (reporte['fechaCreacion'] is Timestamp) {
      try { fechaFormateada = DateFormat('dd/MM/yyyy HH:mm', 'es_ES').format((reporte['fechaCreacion'] as Timestamp).toDate()); } 
      catch (e) { print("[DATE_FORMAT_ERROR] $e"); fechaFormateada = (reporte['fechaCreacion'] as Timestamp).toDate().toLocal().toString().substring(0,16); }
    } else if (reporte['fechaCreacionLocal'] is String) {
      try { DateTime dt = DateTime.parse(reporte['fechaCreacionLocal']); fechaFormateada = DateFormat('dd/MM/yyyy HH:mm', 'es_ES').format(dt); } 
      catch (e) { print("[DATE_FORMAT_ERROR] $e"); fechaFormateada = reporte['fechaCreacionLocal']; }
    }
    showModalBottomSheet(
      context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20,20,20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: SingleChildScrollView(child: Column( mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row( children: [ Icon(categoryStyle['iconData'], color: categoryStyle['color'], size: 36), const SizedBox(width: 12), Expanded(child: Text(reporte['titulo'] ?? 'Sin título', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))), ], ),
            const SizedBox(height: 16),
            if (imageUrl.isNotEmpty) Center( child: ClipRRect( borderRadius: BorderRadius.circular(10), child: Image.network( imageUrl, height: 200, fit: BoxFit.cover,
                  loadingBuilder: (ctx, child, progress) => progress == null ? child : Container(height: 200, child: Center(child: CircularProgressIndicator(value: progress.expectedTotalBytes != null ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null))),
                  errorBuilder: (ctx, err, st) => Container(height: 150, color: Colors.grey[200], child: Center(child: Icon(Icons.broken_image, size: 50, color: Colors.grey[400]))),
            ))),
            if (imageUrl.isNotEmpty) const SizedBox(height: 16),
            _buildDetailRow("Tipo:", "${categoryStyle['name']} (${reporte['tipo']})"),
            _buildDetailRow("Nivel de Riesgo:", reporte['nivelRiesgo'] ?? 'N/A'),
            _buildDetailRow("Descripción:", reporte['descripcion'] ?? 'N/A'),
            _buildDetailRow("Estado:", reporte['estado'] ?? 'N/A'),
            _buildDetailRow("Etapa:", reporte['etapa'] ?? 'N/A'),
            _buildDetailRow("Fecha:", fechaFormateada),
            const SizedBox(height: 20),
            Center(child: ElevatedButton(child: const Text('Cerrar'), onPressed: () => Navigator.of(context).pop())),
          ],)),),);
  }
  Widget _buildDetailRow(String label, String value) => Padding( 
    padding: const EdgeInsets.symmetric(vertical: 6.0),
    child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text("$label ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Expanded(child: Text(value, style: const TextStyle(fontSize: 15))), ], ),
  );
  Future<void> _preguntarUsoUbicacionActual() async { 
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    bool? usarUbicacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usar ubicación actual'), content: const Text('¿Deseas usar tu ubicación actual como punto de origen?'),
        actions: [ TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')), ],
      ),
    );
    if (usarUbicacion == true) await _usarUbicacionActualComoOrigen();
  }
  Future<String> _getAddressFromLatLng(LatLng latLng) async { 
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        Placemark p = placemarks.first; List<String> addressParts = [];
        if (p.street != null && p.street!.isNotEmpty) addressParts.add(p.street!);
        if (p.subLocality != null && p.subLocality!.isNotEmpty) addressParts.add(p.subLocality!);
        if (p.locality != null && p.locality!.isNotEmpty) addressParts.add(p.locality!);
        if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) addressParts.add(p.subAdministrativeArea!);
        String resultAddress = addressParts.join(', ');
        return resultAddress.isNotEmpty ? resultAddress : "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
      }
    } catch (e) { print("[GEOCODING_ERROR] _getAddressFromLatLng: $e"); }
    return "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
  }
  Future<void> _updateOriginMarker(LatLng position, String title) async { 
    if (!mounted) return;
    _origenIcon ??= await _bitmapDescriptorFromIconData(Icons.person_pin_circle, Colors.blue, size: 72.0, isOriginMarker: true);
    final marker = Marker(markerId: const MarkerId('origen'), position: position, infoWindow: InfoWindow(title: title), icon: _origenIcon!, zIndex: 3);
    setState(() { _markers.removeWhere((m) => m.markerId.value == 'origen'); _markers.add(marker); });
  }
  void _updateDestMarker(String id, LatLng position, String title, double hue) { 
    if (!mounted) return;
    final marker = Marker(markerId: MarkerId(id), position: position, infoWindow: InfoWindow(title: title), icon: BitmapDescriptor.defaultMarkerWithHue(hue));
    setState(() { _markers.removeWhere((m) => m.markerId == MarkerId(id)); _markers.add(marker); });
  }
  Future<void> _usarUbicacionActualComoOrigen() async { 
    print("[LOCATION] Usando ubicación actual como origen...");
    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!servicioHabilitado) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Habilita el servicio de ubicación.'))); return; }
    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permiso denegado.'))); return; }
    }
    if (permiso == LocationPermission.deniedForever && mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permiso denegado permanentemente.'))); return; }
    try {
      Position posicion = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final origenLatLng = LatLng(posicion.latitude, posicion.longitude);
      String direccion = await _getAddressFromLatLng(origenLatLng);
      if (mounted) {
        _origenLatLng = origenLatLng; 
        origenController.text = direccion;
        await _updateOriginMarker(origenLatLng, "Origen: Actual"); 
        setState(() { _clearAllPolylinesAndCache(); });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(origenLatLng, 15));
         print("[LOCATION] Origen fijado: $direccion ($origenLatLng)");
      }
    } catch (e) {
      print("[LOCATION_ERROR] $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al obtener ubicación: $e')));
        setState(() { origenController.clear(); _origenLatLng = null; _markers.removeWhere((m) => m.markerId.value == 'origen'); _clearAllPolylinesAndCache(); });
      }
    }
  }
  Future<void> _getPlaceSuggestions(String query, {bool forOrigin = false}) async { 
    if (query.isEmpty) { if (mounted) setState(() => _placeSuggestions = []); return; }
    if (_isFetchingSuggestions) return;
    if (mounted) setState(() => _isFetchingSuggestions = true);
     g_places.Location? locationBias = _origenLatLng != null ? g_places.Location(lat: _origenLatLng!.latitude, lng: _origenLatLng!.longitude) : g_places.Location(lat: _kInitialPosition.target.latitude, lng: _kInitialPosition.target.longitude);
    final response = await _places.autocomplete(query, location: locationBias, radius: 50000, language: 'es', components: [g_places.Component("country", "pe")]);
    if (mounted) {
      if (response.isOkay) setState(() => _placeSuggestions = response.predictions);
      else { print("[PLACES_API_ERROR] Autocomplete: ${response.errorMessage}"); setState(() => _placeSuggestions = []); }
      setState(() => _isFetchingSuggestions = false);
    }
  }
  Future<void> _getPlaceDetailsAndSet(g_places.Prediction suggestion, {required bool isOrigin}) async { 
    if (suggestion.placeId == null) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo obtener detalles.'))); return; }
     final detailsResponse = await _places.getDetailsByPlaceId(suggestion.placeId!);
    if (mounted) {
      if (detailsResponse.isOkay && detailsResponse.result.geometry != null) {
        final lat = detailsResponse.result.geometry!.location.lat; final lng = detailsResponse.result.geometry!.location.lng;
        final placeLatLng = LatLng(lat, lng); String placeDescription = suggestion.description ?? "$lat, $lng";
        
        if (isOrigin) {
            origenController.text = placeDescription; _origenLatLng = placeLatLng;
            await _updateOriginMarker(placeLatLng, "Origen: ${suggestion.structuredFormatting?.mainText ?? ''}"); 
            print("[PLACES] Origen de sugerencia: $placeDescription ($placeLatLng)");
        } else {
            destinoController.text = placeDescription; _destinoLatLng = placeLatLng;
            _updateDestMarker('destino', placeLatLng, "Destino: ${suggestion.structuredFormatting?.mainText ?? ''}", BitmapDescriptor.hueRed);
            print("[PLACES] Destino de sugerencia: $placeDescription ($placeLatLng)");
        }
        setState(() { 
          _placeSuggestions.clear();
          _clearAllPolylinesAndCache();
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(placeLatLng, 15));
      } else {
        print("[PLACES_API_ERROR] GetDetails: ${detailsResponse.errorMessage}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al obtener detalles: ${detailsResponse.errorMessage}')));
      }
    }
  }
  Future<LatLng?> _geocodeAddress(String address) async { 
    if (address.isEmpty) return null;
    print("[GEOCODING] Geocodificando: $address");
    try {
      final response = await _places.searchByText(address, location: g_places.Location(lat: _kInitialPosition.target.latitude, lng: _kInitialPosition.target.longitude), radius: 50000, language: 'es', region: 'pe');
      if (response.isOkay && response.results.isNotEmpty) {
        final geom = response.results.first.geometry;
        if (geom != null) { print("[GEOCODING] Places API: ${geom.location.lat}, ${geom.location.lng}"); return LatLng(geom.location.lat, geom.location.lng); }
      }
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) { print("[GEOCODING] Geocoding Pkg: ${locations.first.latitude}, ${locations.first.longitude}"); return LatLng(locations.first.latitude, locations.first.longitude); }
    } catch (e) { print("[GEOCODING_ERROR] '$address': $e"); }
    print("[GEOCODING] Falló: $address"); return null;
  }
  void _clearAllPolylinesAndCache() { 
    if (mounted) setState(() => _polylines.clear());
    _routeCache.clear();
    print("[ROUTE] Polilíneas y caché limpiados.");
  }
  Future<void> _handleMapTap(LatLng tappedPoint) async { 
    if (!mounted) return;
    print("[MAP_TAP] Punto: $tappedPoint");
     final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Seleccionar Punto'), content: const Text('¿Usar como origen o destino?'),
        actions: <Widget>[ TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(context).pop(null)), TextButton(child: const Text('Origen', style: TextStyle(color: Colors.blue)), onPressed: () => Navigator.of(context).pop('origen')), TextButton(child: const Text('Destino', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(context).pop('destino')), ],
      ),
    );
    if (choice == null || !mounted) { print("[MAP_TAP] Cancelado."); return; }
    String address = await _getAddressFromLatLng(tappedPoint);
    
    if (choice == 'origen') {
      origenController.text = address; _origenLatLng = tappedPoint;
      await _updateOriginMarker(tappedPoint, "Origen: Mapa"); 
      print("[MAP_TAP] Origen desde mapa: $address ($tappedPoint)");
    } else if (choice == 'destino') {
      destinoController.text = address; _destinoLatLng = tappedPoint;
      _updateDestMarker('destino', tappedPoint, "Destino: Mapa", BitmapDescriptor.hueRed);
      print("[MAP_TAP] Destino desde mapa: $address ($tappedPoint)");
    }
    setState(() { 
        _clearAllPolylinesAndCache();
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(tappedPoint));
  }

  Future<void> _getAndDisplayRoute({ 
    required LatLng origin, 
    required LatLng destination, 
    required RouteType routeType, 
    List<LatLng> detourWaypoints = const [], 
    bool fetchAlternativesForSafeRoute = false 
  }) async {
    String routeTypeStr = routeType.toString().split('.').last;
    String detourHash = detourWaypoints.isNotEmpty ? "_detour_${detourWaypoints.map((p) => p.hashCode).join('_')}" : "";
    String polylineIdStr = routeType == RouteType.normal ? _normalRouteId : "$_safeRouteId$detourHash";
    
    Color routeColor = routeType == RouteType.normal ? Colors.lightBlueAccent : Colors.green.shade600;
    if(detourWaypoints.isNotEmpty && routeType == RouteType.safe) routeColor = Colors.green.shade800;
    double routeZIndex = routeType == RouteType.normal ? 1 : 2; 
    
    String cacheKey = "${origin.latitude},${origin.longitude}_${destination.latitude},${destination.longitude}_$routeTypeStr$detourHash" 
                      + (fetchAlternativesForSafeRoute && detourWaypoints.isEmpty ? "_google_alt" : "");


    if (_routeCache.containsKey(cacheKey)) {
      print("[ROUTE_CACHE] Ruta $polylineIdStr desde caché: $cacheKey");
      final cachedData = _routeCache[cacheKey]!;
      if (mounted) setState(() {
        _polylines.removeWhere((p) => p.polylineId == PolylineId(cachedData.polylineId));
        _polylines.add(Polyline(polylineId: PolylineId(cachedData.polylineId), points: cachedData.coordinates, color: cachedData.color, width: 6, zIndex: cachedData.zIndex.toInt()));
        if (routeType == RouteType.normal) _normalRouteInfo = "${cachedData.distanceText ?? ''}, ${cachedData.durationText ?? ''}";
        else _safeRouteInfo = "${cachedData.distanceText ?? ''}, ${cachedData.durationText ?? ''} ${cachedData.isDetour ? '(Ruta Segura con Desvío)' : '(Ruta Segura - Alternativa Google)'}";
      }); return;
    }

    print("[ROUTE_API] Solicitando ruta $polylineIdStr...");
    String url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&language=es&key=$GOOGLE_MAPS_API_KEY';
    
    if (detourWaypoints.isNotEmpty) {
        String waypointsString = detourWaypoints.map((p) => "via:${p.latitude},${p.longitude}").join('|');
        url += '&waypoints=$waypointsString';
        print("[ROUTE_API] Usando waypoints de desvío: $waypointsString");
    } else if (routeType == RouteType.safe && fetchAlternativesForSafeRoute) {
      url += '&alternatives=true'; 
      print("[ROUTE_API] Solicitando alternativas de Google para Ruta Segura.");
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          int routeIdxToUse = 0;
          if (routeType == RouteType.safe && detourWaypoints.isEmpty && fetchAlternativesForSafeRoute && data['routes'].length > 1) {
              routeIdxToUse = 1; 
              print("[ROUTE_API] Ruta Segura: Usando alternativa de Google (índice 1).");
          }

           final apiRoute = data['routes'][routeIdxToUse]; 
           final leg = apiRoute['legs'][0];
           String distanceText = leg['distance']?['text'] ?? 'N/A';
           String durationText = leg['duration']?['text'] ?? 'N/A';
           List<dynamic> steps = leg['steps']; List<LatLng> routeCoordinates = [];
          for (var step in steps) routeCoordinates.addAll(_decodePolyline(step['polyline']['points']));
          
          if (routeCoordinates.isEmpty && mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se decodificó ruta $polylineIdStr.'))); return; }
          print("[ROUTE_API] Ruta $polylineIdStr decodificada: ${routeCoordinates.length} puntos. Dist: $distanceText, Dur: $durationText");
          
          final polylineData = PolylineData(
            coordinates: routeCoordinates, color: routeColor, polylineId: polylineIdStr, zIndex: routeZIndex,
            distanceText: distanceText, durationText: durationText, isDetour: detourWaypoints.isNotEmpty
          );
          _routeCache[cacheKey] = polylineData;

          if (mounted) {
            setState(() {
              if (routeType == RouteType.normal) {
                  _polylines.removeWhere((p) => p.polylineId.value == _normalRouteId);
              } else { 
                  _polylines.removeWhere((p) => p.polylineId.value.startsWith(_safeRouteId));
              }
              _polylines.add(Polyline(polylineId: PolylineId(polylineIdStr), points: routeCoordinates, color: routeColor, width: 6, zIndex: routeZIndex.toInt()));
              
              if (routeType == RouteType.normal) _normalRouteInfo = "$distanceText, $durationText";
              else _safeRouteInfo = "$distanceText, $durationText ${detourWaypoints.isNotEmpty ? '(Ruta Segura con Desvío)' : '(Ruta Segura - Alternativa Google)'}";
            });
            
            bool shouldAnimate = (routeType == RouteType.normal && _polylines.where((p)=> p.polylineId.value.startsWith(_safeRouteId)).isEmpty) || 
                                 (routeType == RouteType.safe);
            if (shouldAnimate || _polylines.length == 1) {
                 _mapController?.animateCamera(CameraUpdate.newLatLngBounds(_boundsFromLatLngList(routeCoordinates), 70));
            }
          }
        } else {  print("[DIRECTIONS_API_ERROR] ($polylineIdStr): ${data['status']} - ${data['error_message']}"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se encontró ruta $polylineIdStr: ${data['status']}'))); }
      } else { print("[HTTP_ERROR] ($polylineIdStr): ${response.statusCode}"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error API ruta $polylineIdStr: ${response.statusCode}'))); }
    } catch (e) { print("[EXCEPTION] ($polylineIdStr): $e"); if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Excepción ruta $polylineIdStr: $e'))); }
  }

  List<LatLng> _calculateDetourWaypointsForZone( LatLng origin, LatLng destination, LatLng zoneCenter, double zoneRadiusDegrees, List<LatLng> normalRoutePolyline) {
    print("[DETOUR_CALC] Calculando desvío para zona en $zoneCenter");
    if (normalRoutePolyline.length < 2) return [];
    List<LatLng> detourWaypoints = [];
    
    LatLng closestPointOnNormalRoute = normalRoutePolyline.first;
    double minDistanceToZone = double.infinity;
    int entrySegmentIndex = -1; 

    for (int i = 0; i < normalRoutePolyline.length; i++) {
        double dist = _calculateDistanceHaversine(normalRoutePolyline[i], zoneCenter);
        if (dist < minDistanceToZone) {
            minDistanceToZone = dist;
            closestPointOnNormalRoute = normalRoutePolyline[i];
            if (i > 0) entrySegmentIndex = i -1; else entrySegmentIndex = 0;
        }
    }

    double zoneRadiusMeters = zoneRadiusDegrees * 111000; 
    if (minDistanceToZone > zoneRadiusMeters * 1.5) { 
        print("[DETOUR_CALC] Ruta normal ya está suficientemente lejos de la zona $zoneCenter. No se requieren waypoints de desvío.");
        return [];
    }
    
    print("[DETOUR_CALC] Punto más cercano en ruta normal a zona ($zoneCenter): $closestPointOnNormalRoute. Distancia: ${minDistanceToZone.toStringAsFixed(0)}m");

    LatLng pointBeforeZone = entrySegmentIndex > 0 ? normalRoutePolyline[entrySegmentIndex] : origin;
    int exitSegmentCandidateIndex = entrySegmentIndex + 2 < normalRoutePolyline.length ? entrySegmentIndex + 2 : normalRoutePolyline.length -1;
    LatLng pointAfterZone = normalRoutePolyline[exitSegmentCandidateIndex];

    double routeSegmentDx = pointAfterZone.longitude - pointBeforeZone.longitude;
    double routeSegmentDy = pointAfterZone.latitude - pointBeforeZone.latitude;
    double perpDx = -routeSegmentDy;
    double perpDy = routeSegmentDx;
    double magnitude = sqrt(perpDx * perpDx + perpDy * perpDy);

    if (magnitude < 0.00001) { 
        perpDx = -(destination.latitude - origin.latitude);
        perpDy = destination.longitude - origin.longitude;
        magnitude = sqrt(perpDx * perpDx + perpDy * perpDy);
        if (magnitude < 0.00001) {print("[DETOUR_CALC] No se pudo determinar vector perpendicular."); return []; }
    }
    perpDx /= magnitude;
    perpDy /= magnitude;

    double detourDistanceDegrees = DETOUR_OFFSET_DEGREES + zoneRadiusDegrees;
    LatLng detourWaypoint = LatLng(zoneCenter.latitude + perpDy * detourDistanceDegrees, zoneCenter.longitude + perpDx * detourDistanceDegrees);
    
    detourWaypoints.add(detourWaypoint);
    print("[DETOUR_CALC] Waypoint de desvío generado: $detourWaypoint");
    return detourWaypoints;
}

  double _calculateDistanceHaversine(LatLng p1, LatLng p2) { /* ... sin cambios ... */ 
    const R = 6371e3; 
    final phi1 = p1.latitude * pi / 180; final phi2 = p2.latitude * pi / 180;
    final deltaPhi = (p2.latitude - p1.latitude) * pi / 180;
    final deltaLambda = (p2.longitude - p1.longitude) * pi / 180;
    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; 
  }
  bool _isPointOnSegmentAndNear(LatLng point, LatLng segP1, LatLng segP2, double thresholdMeters) { /* ... sin cambios ... */ 
    double distToP1 = _calculateDistanceHaversine(point, segP1);
    double distToP2 = _calculateDistanceHaversine(point, segP2);
    double segLength = _calculateDistanceHaversine(segP1, segP2);
    if (distToP1 < thresholdMeters || distToP2 < thresholdMeters) return true;
    if (distToP1 + distToP2 < segLength + thresholdMeters * 2) { 
        return true;
    }
    return false;
  }


  Future<void> _showAllRoutes() async {
    print("[UI_ACTION] Mostrar Rutas presionado.");
    // Validaciones de origen y destino...
    if (_origenLatLng == null && origenController.text.isNotEmpty) {
      final geocodedOrigin = await _geocodeAddress(origenController.text);
      if (geocodedOrigin != null && mounted) { _origenLatLng = geocodedOrigin; await _updateOriginMarker(geocodedOrigin, "Origen: ${origenController.text}"); } 
      else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Origen no válido.'))); return; }
    }
    if (_destinoLatLng == null && destinoController.text.isNotEmpty) {
      final geocodedDestino = await _geocodeAddress(destinoController.text);
      if (geocodedDestino != null && mounted) { _destinoLatLng = geocodedDestino; _updateDestMarker('destino', geocodedDestino, "Destino: ${destinoController.text}", BitmapDescriptor.hueRed); } 
      else { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Destino no válido.'))); return; }
    }
    if (_origenLatLng == null || _destinoLatLng == null) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona origen y destino.'))); return; }
    
    if(mounted) setState(() { _polylines.clear(); _normalRouteInfo = null; _safeRouteInfo = null; });
    _routeCache.clear();

    // 1. Obtener y mostrar ruta normal
    await _getAndDisplayRoute(origin: _origenLatLng!, destination: _destinoLatLng!, routeType: RouteType.normal);
    
    String normalRouteCacheKey = "${_origenLatLng!.latitude},${_origenLatLng!.longitude}_${_destinoLatLng!.latitude},${_destinoLatLng!.longitude}_${RouteType.normal.toString().split('.').last}";
    PolylineData? normalRouteData = _routeCache[normalRouteCacheKey];

    if (normalRouteData == null || normalRouteData.coordinates.isEmpty) {
        print("[AVOIDANCE] No se pudo obtener la ruta normal para calcular desvíos. Intentando alternativa de Google para ruta segura.");
        await _getAndDisplayRoute(origin: _origenLatLng!, destination: _destinoLatLng!, routeType: RouteType.safe, fetchAlternativesForSafeRoute: true);
        return;
    }

    // 2. Lógica de evitación: ahora considera CUALQUIER reporte filtrado por tiempo cercano
    List<Map<String, dynamic>> reportsNearRouteForAvoidance = _filteredActiveReports.where((reporte) {
      final ubicacion = reporte['ubicacion']; 
      LatLng puntoReporte = LatLng(ubicacion['latitud'].toDouble(), ubicacion['longitud'].toDouble());
      // Verificar si el reporte está cerca de CUALQUIER punto de la ruta normal
      for (LatLng routePoint in normalRouteData.coordinates) {
          if (_calculateDistanceHaversine(routePoint, puntoReporte) < REPORT_INFLUENCE_RADIUS_METERS) {
              return true; // Este reporte está lo suficientemente cerca de la ruta normal
          }
      }
      return false;
    }).toList();


    if (reportsNearRouteForAvoidance.isNotEmpty) {
        print("--- [AVOIDANCE] ${reportsNearRouteForAvoidance.length} reporte(s) cercano(s) a la ruta normal. Intentando desvío. ---");
        
        // Calcular un centroide de todos los reportes problemáticos para definir la zona a evitar
        double sumLat = 0, sumLng = 0;
        for(var r in reportsNearRouteForAvoidance) { 
            sumLat += r['ubicacion']['latitud'];
            sumLng += r['ubicacion']['longitud']; 
        }
        LatLng mainCongestionCenter = LatLng(sumLat / reportsNearRouteForAvoidance.length, sumLng / reportsNearRouteForAvoidance.length);
        print("[AVOIDANCE] Centro de zona a evitar (basado en reportes cercanos): $mainCongestionCenter");
        
        List<LatLng> detourWps = _calculateDetourWaypointsForZone(
            _origenLatLng!, _destinoLatLng!, 
            mainCongestionCenter, DETOUR_CALCULATION_RADIUS_DEGREES, // Usar el radio para el cálculo del desvío
            normalRouteData.coordinates
        );

        if (detourWps.isNotEmpty) {
            await _getAndDisplayRoute(
                origin: _origenLatLng!, destination: _destinoLatLng!, 
                routeType: RouteType.safe, detourWaypoints: detourWps
            );
            return; 
        } else {
           print("[AVOIDANCE] No se pudieron calcular waypoints de desvío. Intentando alternativa de Google.");
        }
    } else {
        print("[AVOIDANCE] Ningún reporte (filtrado por tiempo) está lo suficientemente cerca de la ruta normal para requerir desvío.");
    }
    
    // Fallback: si no hay reportes cercanos que justifiquen desvío, o el desvío falló,
    // intentar una alternativa de Google para la "Ruta Segura"
    print("[AVOIDANCE_FALLBACK] Intentando con &alternatives=true para Ruta Segura.");
    await _getAndDisplayRoute(origin: _origenLatLng!, destination: _destinoLatLng!, routeType: RouteType.safe, fetchAlternativesForSafeRoute: true);
  }

  // --- FUNCIONES AUXILIARES RESTAURADAS ---
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double x0 = list.first.latitude;
    double x1 = list.first.latitude;
    double y0 = list.first.longitude;
    double y1 = list.first.longitude;
    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }
    return LatLngBounds(northeast: LatLng(x1, y1), southwest: LatLng(x0, y0));
  }
  // --- FIN FUNCIONES AUXILIARES RESTAURADAS ---


  // --- MÉTODO BUILD RESTAURADO ---
  @override
  Widget build(BuildContext context) {
    print("[BUILD] Reconstruyendo widget principal.");
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ruta Segura"), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [ 
          PopupMenuButton<TimeFilter>(
            icon: const Icon(Icons.filter_list), tooltip: "Filtrar reportes",
            onSelected: (TimeFilter result) {
              if (_selectedTimeFilter != result) { setState(() { _selectedTimeFilter = result; });
                print("[UI_ACTION] Filtro tiempo: ${timeFilterToString(result)}"); _applyTimeFilterToReports(); }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<TimeFilter>>[
              PopupMenuItem<TimeFilter>(value: TimeFilter.all, child: Text(timeFilterToString(TimeFilter.all))),
              PopupMenuItem<TimeFilter>(value: TimeFilter.last24Hours, child: Text(timeFilterToString(TimeFilter.last24Hours))),
              PopupMenuItem<TimeFilter>(value: TimeFilter.last12Hours, child: Text(timeFilterToString(TimeFilter.last12Hours))),
              PopupMenuItem<TimeFilter>(value: TimeFilter.last1Hour, child: Text(timeFilterToString(TimeFilter.last1Hour))),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Recargar reportes', onPressed: () { print("[UI_ACTION] Recargar Reportes."); _fetchAllActiveReports(); }) 
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal, initialCameraPosition: _kInitialPosition,
            zoomControlsEnabled: true, myLocationEnabled: true, myLocationButtonEnabled: true,
            markers: _markers, polylines: _polylines,
            onMapCreated: (GoogleMapController controller) { _mapController = controller; print("[MAP] Mapa creado."); },
            onTap: _handleMapTap,
          ),
          Positioned(
            top: 10, left: 10, right: 10,
            child: Card( elevation: 4, child: Padding( padding: const EdgeInsets.all(8.0),
              child: Column( mainAxisSize: MainAxisSize.min, children: [
                Focus(
                  onFocusChange: (hasFocus) async { if (mounted) setState(() => _isOriginFieldFocused = hasFocus); if (!hasFocus && origenController.text.isNotEmpty && _origenLatLng == null) {
                      final latLng = await _geocodeAddress(origenController.text); if (latLng != null && mounted) { _origenLatLng = latLng; await _updateOriginMarker(latLng, "Origen: ${origenController.text}"); setState(() { _clearAllPolylinesAndCache(); });  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15)); }
                    } else if (hasFocus && mounted) setState(() => _placeSuggestions.clear());
                  },
                  child: TextFormField( controller: origenController, decoration: InputDecoration( hintText: 'Origen', prefixIcon: const Icon(Icons.my_location), suffixIcon: origenController.text.isNotEmpty ? IconButton( icon: const Icon(Icons.clear), onPressed: () { if (mounted) setState(() { origenController.clear(); _origenLatLng = null; _markers.removeWhere((m) => m.markerId.value == 'origen'); _placeSuggestions.clear(); _clearAllPolylinesAndCache(); print("[UI] Origen limpiado."); }); }) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.white, ),
                    onChanged: (value) { if (_isOriginFieldFocused) _getPlaceSuggestions(value, forOrigin: true); },
                    onFieldSubmitted: (value) async { if (value.isNotEmpty) { FocusScope.of(context).unfocus(); final latLng = await _geocodeAddress(value); if (latLng != null && mounted) { _origenLatLng = latLng; await _updateOriginMarker(latLng, "Origen: $value"); setState(() { _clearAllPolylinesAndCache(); }); _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15)); } else if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró origen.'))); } },
                  ),
                ),
                const SizedBox(height: 8),
                Focus(
                  onFocusChange: (hasFocus) { if (mounted) setState(() => _isOriginFieldFocused = !hasFocus); if (!hasFocus && destinoController.text.isNotEmpty && _destinoLatLng == null) {
                      _geocodeAddress(destinoController.text).then((latLng) { if (latLng != null && mounted) { _destinoLatLng = latLng; _updateDestMarker('destino', latLng, "Destino: ${destinoController.text}", BitmapDescriptor.hueRed); setState(() { _clearAllPolylinesAndCache(); });  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15)); } });
                    } else if (hasFocus && mounted) setState(() => _placeSuggestions.clear());
                  },
                  child: TextFormField( controller: destinoController, decoration: InputDecoration( hintText: 'Destino', prefixIcon: const Icon(Icons.location_on),  suffixIcon: destinoController.text.isNotEmpty ? IconButton( icon: const Icon(Icons.clear), onPressed: () { if (mounted) setState(() { destinoController.clear(); _destinoLatLng = null; _markers.removeWhere((m) => m.markerId.value == 'destino'); _placeSuggestions.clear(); _clearAllPolylinesAndCache(); print("[UI] Destino limpiado."); }); }) : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.white, ),
                    onChanged: (value) { if (!_isOriginFieldFocused) _getPlaceSuggestions(value, forOrigin: false);},
                    onFieldSubmitted: (value) async { if (value.isNotEmpty) { FocusScope.of(context).unfocus(); final latLng = await _geocodeAddress(value); if (latLng != null && mounted) { _destinoLatLng = latLng; _updateDestMarker('destino', latLng, "Destino: $value", BitmapDescriptor.hueRed); setState(() { _clearAllPolylinesAndCache(); });  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15)); } else if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró destino.'))); } },
                  ),
                ),
                if (_placeSuggestions.isNotEmpty) _buildSuggestionsList(),
                const SizedBox(height: 10),
                ElevatedButton.icon( icon: const Icon(Icons.alt_route), onPressed: _showAllRoutes, label: const Text("Mostrar Rutas"), style: ElevatedButton.styleFrom( backgroundColor: Theme.of(context).colorScheme.secondary, foregroundColor: Theme.of(context).colorScheme.onSecondary, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12), textStyle: const TextStyle(fontSize: 16) ), ),
                if (_normalRouteInfo != null) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text("Ruta Normal: $_normalRouteInfo", style: TextStyle(color: Colors.blue.shade700, fontSize: 12))),
                if (_safeRouteInfo != null) Padding(padding: const EdgeInsets.only(top: 4.0), child: Text("$_safeRouteInfo", style: TextStyle(color: Colors.green.shade700, fontSize: 12))),
              ],),
            ),),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() { 
     return Material(
      elevation: 2,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 180),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [ BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2)), ],),
        child: ListView.builder(
          shrinkWrap: true, itemCount: _placeSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = _placeSuggestions[index];
            return ListTile(
              leading: const Icon(Icons.location_pin, color: Colors.grey),
              title: Text(suggestion.structuredFormatting?.mainText ?? suggestion.description ?? ''),
              subtitle: Text(suggestion.structuredFormatting?.secondaryText ?? ''),
              onTap: () { FocusScope.of(context).unfocus(); _getPlaceDetailsAndSet(suggestion, isOrigin: _isOriginFieldFocused); },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() { 
    print("[DISPOSE] Liberando controladores.");
    origenController.dispose();
    destinoController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}

extension StringExtension on String { 
    String capitalize() {
      if (this.isEmpty) return "";
      return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
    }
}