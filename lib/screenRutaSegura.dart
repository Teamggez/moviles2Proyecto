import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart';
import 'package:http/http.dart' as http;

class ScreenRutaSegura extends StatefulWidget {
  const ScreenRutaSegura({super.key});

  @override
  State<ScreenRutaSegura> createState() => _ScreenRutaSeguraState();
}

class _ScreenRutaSeguraState extends State<ScreenRutaSegura> {
  GoogleMapController? _mapController;
  final TextEditingController origenController = TextEditingController();
  final TextEditingController destinoController = TextEditingController();
  final _places = GoogleMapsPlaces(apiKey: 'AIzaSyAQUDQHmghORIaVpnYBlfKWrLXe_Tnm4P8');

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(-18.0146, -70.2534), // Tacna, Peru
    zoom: 13.0,
  );

  List<LatLng> _routeCoordinates = [];
  Set<Polyline> _polylines = {};
  List<String> _placeSuggestions = [];
  bool _isFetchingSuggestions = false; // To prevent rapid firing

  Future<void> _getPlaceSuggestions(String query) async {
    if (_isFetchingSuggestions) return; // Prevent multiple simultaneous requests
    if (query.isEmpty) {
      setState(() {
        _placeSuggestions = [];
      });
      return;
    }

    setState(() {
      _isFetchingSuggestions = true;
    });

    final response = await _places.autocomplete(query,
        location: Location(lat: -18.0146, lng: -70.2534), radius: 50000);

    if (mounted) { 
      if (response.status == "OK") {
        setState(() {
          _placeSuggestions = response.predictions
              .map((p) => p.description ?? '')
              .toList();
        });
      } else {
        print("Places API error: ${response.errorMessage}");
        setState(() {
          _placeSuggestions = [];
        });
      }
      setState(() {
        _isFetchingSuggestions = false;
      });
    }
  }

  Future<void> _getRoute() async {
    final origen = origenController.text;
    final destino = destinoController.text;

    if (origen.isEmpty || destino.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, ingresa ambos campos de origen y destino.')),
        );
      }
      return;
    }
    String url = 'https://maps.googleapis.com/maps/api/directions/json?origin=$origen&destination=$destino&key=AIzaSyAQUDQHmghORIaVpnYBlfKWrLXe_Tnm4P8';

    try {
      final response = await http.get(Uri.parse(url));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'].isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se encontró una ruta.')),
          );
          return;
        }

        List<dynamic> steps = data['routes'][0]['legs'][0]['steps'];
        _routeCoordinates.clear();

        for (var step in steps) {
          var polyline = step['polyline']['points'];
          _routeCoordinates.addAll(_decodePolyline(polyline));
        }

        setState(() {
          _polylines.clear(); 
          _polylines.add(Polyline(
            polylineId: const PolylineId('ruta_segura'),
            points: _routeCoordinates,
            color: Colors.blue,
            width: 5,
          ));
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener la ruta: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (mounted) { // Check if widget is still mounted
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocurrió un error: $e')),
        );
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ruta Segura"),
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _kInitialPosition,
            zoomControlsEnabled: false,
            myLocationEnabled: true,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
            },
            polylines: _polylines,
          ),
          Positioned(
            top: 20,
            left: 10,
            right: 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: origenController,
                  decoration: const InputDecoration(
                    hintText: 'Origen (dirección o coordenadas)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: destinoController,
                  decoration: const InputDecoration(
                    hintText: 'Destino (dirección o coordenadas)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                     _getPlaceSuggestions(value);
                  },
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _getRoute,
                  child: const Text("Calcular ruta segura"),
                ),
                if (_placeSuggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150.0,
                    child: Card( 
                      child: ListView.builder(
                        itemCount: _placeSuggestions.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(_placeSuggestions[index]),
                            onTap: () {
                              destinoController.text = _placeSuggestions[index];
                              setState(() {
                                _placeSuggestions = [];
                              });
                              FocusScope.of(context).unfocus();
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}