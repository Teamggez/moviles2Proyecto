import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart' as g_places;
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// TODO:  GOOGLE CLOUD
// 
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

class _ScreenRutaSeguraState extends State<ScreenRutaSegura> {
  GoogleMapController? _mapController;
  final TextEditingController origenController = TextEditingController();
  final TextEditingController destinoController = TextEditingController();

  final _places = g_places.GoogleMapsPlaces(
    apiKey: GOOGLE_MAPS_API_KEY,
  );

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(-18.0146, -70.2534), // Tacna, Peru
    zoom: 13.0,
  );

  List<LatLng> _routeCoordinates = [];
  Set<Polyline> _polylines = {};
  List<g_places.Prediction> _placeSuggestions = [];
  bool _isFetchingSuggestions = false;
  bool _isOriginFieldFocused = false;

  Set<Marker> _markers = {};

  LatLng? _origenLatLng;
  LatLng? _destinoLatLng;

  @override
  void initState() {
    super.initState();
    _preguntarUsoUbicacionActual();
  }

  Future<void> _preguntarUsoUbicacionActual() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    bool? usarUbicacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usar ubicación actual'),
        content: const Text('¿Deseas usar tu ubicación actual como punto de origen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí')),
        ],
      ),
    );

    if (usarUbicacion == true) {
      await _usarUbicacionActualComoOrigen();
    }
  }

  Future<String> _getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = "";
        if (place.street != null && place.street!.isNotEmpty) address += "${place.street}, ";
        if (place.locality != null && place.locality!.isNotEmpty) address += "${place.locality}, ";
        if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) address += "${place.subAdministrativeArea}, ";
        if (place.country != null && place.country!.isNotEmpty) address += place.country!;
        
        // Limpiar comas extra al final y al principio
        address = address.trim();
        if (address.endsWith(',')) address = address.substring(0, address.length -1);

        if (address.isEmpty && place.name != null) return place.name!; // Fallback al nombre del lugar
        return address.isNotEmpty ? address : "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
      }
    } catch (e) {
      print("Error obteniendo dirección de LatLng: $e");
    }
    return "${latLng.latitude.toStringAsFixed(5)}, ${latLng.longitude.toStringAsFixed(5)}";
  }


  Future<void> _usarUbicacionActualComoOrigen() async {
    bool servicioHabilitado = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!servicioHabilitado) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Por favor habilita el servicio de ubicación.'),
      ));
      return;
    }

    LocationPermission permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await Geolocator.requestPermission();
      if (permiso == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Permiso de ubicación denegado.'),
        ));
        return;
      }
    }
    if (permiso == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Permiso de ubicación denegado permanentemente. Habilítalo desde la configuración.'),
      ));
      return;
    }

    try {
      Position posicion = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final origenLatLng = LatLng(posicion.latitude, posicion.longitude);
      String direccion = await _getAddressFromLatLng(origenLatLng);
      
      if (mounted) {
        setState(() {
          origenController.text = direccion;
          _origenLatLng = origenLatLng;
          _updateMarker('origen', origenLatLng, "Origen: Actual", BitmapDescriptor.hueBlue);
          _clearRoute();
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(origenLatLng, 15));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al obtener ubicación: $e'),
      ));
      setState(() {
        origenController.clear();
        _origenLatLng = null;
        _markers.removeWhere((m) => m.markerId == const MarkerId('origen'));
         _clearRoute();
      });
    }
  }

  Future<void> _getPlaceSuggestions(String query, {bool forOrigin = false}) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _placeSuggestions = []);
      return;
    }
    if (_isFetchingSuggestions) return;

    if (mounted) setState(() => _isFetchingSuggestions = true);

    g_places.Location? locationBias = _origenLatLng != null
        ? g_places.Location(lat: _origenLatLng!.latitude, lng: _origenLatLng!.longitude)
        : g_places.Location(lat: _kInitialPosition.target.latitude, lng: _kInitialPosition.target.longitude);

    final response = await _places.autocomplete(
      query,
      location: locationBias,
      radius: 50000,
      language: 'es',
      components: [g_places.Component("country", "pe")]
    );

    if (mounted) {
      if (response.isOkay) {
        setState(() => _placeSuggestions = response.predictions);
      } else {
        print("Places API autocomplete error: ${response.errorMessage}");
        setState(() => _placeSuggestions = []);
      }
      setState(() => _isFetchingSuggestions = false);
    }
  }

  Future<void> _getPlaceDetailsAndSet(g_places.Prediction suggestion, {required bool isOrigin}) async {
    if (suggestion.placeId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo obtener detalles del lugar.')),
        );
      }
      return;
    }

    final detailsResponse = await _places.getDetailsByPlaceId(suggestion.placeId!);
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
            _updateMarker('origen', placeLatLng, "Origen: ${suggestion.structuredFormatting?.mainText ?? ''}", BitmapDescriptor.hueBlue);
          } else {
            destinoController.text = placeDescription;
            _destinoLatLng = placeLatLng;
            _updateMarker('destino', placeLatLng, "Destino: ${suggestion.structuredFormatting?.mainText ?? ''}", BitmapDescriptor.hueRed);
          }
          _clearRoute();
        });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(placeLatLng, 15));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener detalles: ${detailsResponse.errorMessage}')),
        );
      }
    }
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    if (address.isEmpty) return null;
    try {
      final response = await _places.searchByText(address, 
        location: g_places.Location(lat: _kInitialPosition.target.latitude, lng: _kInitialPosition.target.longitude),
        radius: 50000, language: 'es', region: 'pe'
      );
      if (response.isOkay && response.results.isNotEmpty) {
        final geom = response.results.first.geometry;
        if (geom != null) return LatLng(geom.location.lat, geom.location.lng);
      }
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) return LatLng(locations.first.latitude, locations.first.longitude);
    } catch (e) {
      print("Error geocodificando dirección '$address': $e");
    }
    return null;
  }

  void _updateMarker(String id, LatLng position, String title, double hue) {
    _markers.removeWhere((m) => m.markerId == MarkerId(id));
    _markers.add(
      Marker(
        markerId: MarkerId(id),
        position: position,
        infoWindow: InfoWindow(title: title),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      ),
    );
  }

  void _clearRoute() {
    if (mounted) {
      setState(() {
        _polylines.clear();
        _routeCoordinates.clear();
      });
    }
  }

  Future<void> _handleMapTap(LatLng tappedPoint) async {
    if (!mounted) return;

    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar Punto'),
          content: const Text('¿Deseas establecer este punto como origen o destino?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(null),
            ),
            TextButton(
              child: const Text('Origen', style: TextStyle(color: Colors.blue)),
              onPressed: () => Navigator.of(context).pop('origen'),
            ),
            TextButton(
              child: const Text('Destino', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop('destino'),
            ),
          ],
        );
      },
    );

    if (choice == null || !mounted) return;

    String address = await _getAddressFromLatLng(tappedPoint);

    setState(() {
      _clearRoute();
      if (choice == 'origen') {
        origenController.text = address;
        _origenLatLng = tappedPoint;
        _updateMarker('origen', tappedPoint, "Origen: Mapa", BitmapDescriptor.hueBlue);
      } else if (choice == 'destino') {
        destinoController.text = address;
        _destinoLatLng = tappedPoint;
        _updateMarker('destino', tappedPoint, "Destino: Mapa", BitmapDescriptor.hueRed);
      }
    });
    _mapController?.animateCamera(CameraUpdate.newLatLng(tappedPoint));
  }

  Future<void> _getRoute() async {
    _clearRoute();

    if (_origenLatLng == null && origenController.text.isNotEmpty) {
      final geocodedOrigin = await _geocodeAddress(origenController.text);
      if (geocodedOrigin != null && mounted) {
        setState(() {
          _origenLatLng = geocodedOrigin;
          _updateMarker('origen', _origenLatLng!, "Origen", BitmapDescriptor.hueBlue);
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo encontrar la ubicación de origen.')));
        return;
      }
    }

    if (_destinoLatLng == null && destinoController.text.isNotEmpty) {
      final geocodedDestino = await _geocodeAddress(destinoController.text);
      if (geocodedDestino != null && mounted) {
        setState(() {
          _destinoLatLng = geocodedDestino;
          _updateMarker('destino', _destinoLatLng!, "Destino", BitmapDescriptor.hueRed);
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo encontrar la ubicación de destino.')));
        return;
      }
    }
    
    if (_origenLatLng == null || _destinoLatLng == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona un origen y un destino válidos.')));
      return;
    }

    print('Intentando obtener ruta...');
    print('Origen: Lat=${_origenLatLng!.latitude}, Lng=${_origenLatLng!.longitude}');
    print('Destino: Lat=${_destinoLatLng!.latitude}, Lng=${_destinoLatLng!.longitude}');

    String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${_origenLatLng!.latitude},${_origenLatLng!.longitude}&destination=${_destinoLatLng!.latitude},${_destinoLatLng!.longitude}&mode=driving&language=es&key=$GOOGLE_MAPS_API_KEY';

    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          List<dynamic> steps = data['routes'][0]['legs'][0]['steps'];
          for (var step in steps) {
            _routeCoordinates.addAll(_decodePolyline(step['polyline']['points']));
          }
          if (_routeCoordinates.isEmpty && mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo decodificar la ruta.')));
            return;
          }
          if (mounted) {
            setState(() {
              _polylines.add(Polyline(
                polylineId: const PolylineId('ruta_segura'),
                points: _routeCoordinates,
                color: Colors.deepPurpleAccent, width: 6,
              ));
            });
            _mapController?.animateCamera(CameraUpdate.newLatLngBounds(_boundsFromLatLngList(_routeCoordinates), 70));
          }
        } else {
          print('Directions API Error: ${data['status']} - ${data['error_message']}');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se encontró una ruta: ${data['status']} ${data['error_message'] ?? ''}')));
        }
      } else {
        print('HTTP Error: ${response.statusCode} - ${response.body}');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al obtener la ruta: ${response.statusCode}')));
      }
    } catch (e) {
      print("Excepción al obtener ruta: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ocurrió un error al trazar la ruta: $e')));
    }
  }

  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    assert(list.isNotEmpty);
    double minLat = list[0].latitude, maxLat = list[0].latitude;
    double minLng = list[0].longitude, maxLng = list[0].longitude;
    for (LatLng latLng in list) {
      if (latLng.latitude < minLat) minLat = latLng.latitude;
      if (latLng.latitude > maxLat) maxLat = latLng.latitude;
      if (latLng.longitude < minLng) minLng = latLng.longitude;
      if (latLng.longitude > maxLng) maxLng = latLng.longitude;
    }
    return LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng));
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length, lat = 0, lng = 0;
    while (index < len) {
      int shift = 0, result = 0, byte;
      do { byte = encoded.codeUnitAt(index++) - 63; result |= (byte & 0x1f) << shift; shift += 5; } while (byte >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      shift = 0; result = 0;
      do { byte = encoded.codeUnitAt(index++) - 63; result |= (byte & 0x1f) << shift; shift += 5; } while (byte >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ruta Segura"),
        backgroundColor: Theme.of(context).colorScheme.primary, // Usar colorScheme
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
            },
            onTap: _handleMapTap, // <-- AÑADIDO EL CALLBACK onTap
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
                    Focus(
                      onFocusChange: (hasFocus) {
                        if (mounted) {
                          setState(() {
                            _isOriginFieldFocused = hasFocus;
                            if (!hasFocus && origenController.text.isNotEmpty && _origenLatLng == null) {
                              _geocodeAddress(origenController.text).then((latLng) {
                                if (latLng != null && mounted) {
                                  setState(() {
                                    _origenLatLng = latLng;
                                    _updateMarker('origen', latLng, "Origen: ${origenController.text}", BitmapDescriptor.hueBlue);
                                    _clearRoute();
                                  });
                                  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
                                }
                              });
                            } else if (hasFocus) {
                              _placeSuggestions.clear();
                            }
                          });
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
                                  if (mounted) {
                                    setState(() {
                                      origenController.clear();
                                      _origenLatLng = null;
                                      _markers.removeWhere((m) => m.markerId == const MarkerId('origen'));
                                      _placeSuggestions.clear();
                                      _clearRoute();
                                    });
                                  }
                                },
                              )
                            : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true, fillColor: Colors.white,
                        ),
                        onChanged: (value) { if (_isOriginFieldFocused) _getPlaceSuggestions(value, forOrigin: true); },
                         onFieldSubmitted: (value) async {
                          if (value.isNotEmpty) {
                            FocusScope.of(context).unfocus();
                            final latLng = await _geocodeAddress(value);
                            if (latLng != null && mounted) {
                              setState(() {
                                _origenLatLng = latLng;
                                _updateMarker('origen', latLng, "Origen: $value", BitmapDescriptor.hueBlue);
                                _clearRoute();
                              });
                              _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
                            } else if(mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo encontrar la ubicación de origen.')));
                            }
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                     Focus(
                      onFocusChange: (hasFocus) {
                        if (mounted) {
                          setState(() {
                            _isOriginFieldFocused = !hasFocus; 
                            if (!hasFocus && destinoController.text.isNotEmpty && _destinoLatLng == null) {
                              _geocodeAddress(destinoController.text).then((latLng) {
                                if (latLng != null && mounted) {
                                  setState(() {
                                    _destinoLatLng = latLng;
                                    _updateMarker('destino', latLng, "Destino: ${destinoController.text}", BitmapDescriptor.hueRed);
                                    _clearRoute();
                                  });
                                  _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
                                }
                              });
                            } else if (hasFocus) {
                              _placeSuggestions.clear();
                            }
                          });
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
                                  if (mounted) {
                                    setState(() {
                                      destinoController.clear();
                                      _destinoLatLng = null;
                                      _markers.removeWhere((m) => m.markerId == const MarkerId('destino'));
                                      _placeSuggestions.clear();
                                      _clearRoute();
                                    });
                                  }
                                },
                              )
                            : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true, fillColor: Colors.white,
                        ),
                        onChanged: (value) { if (!_isOriginFieldFocused) _getPlaceSuggestions(value, forOrigin: false);},
                        onFieldSubmitted: (value) async {
                           if (value.isNotEmpty) {
                            FocusScope.of(context).unfocus();
                            final latLng = await _geocodeAddress(value);
                            if (latLng != null && mounted) {
                              setState(() {
                                _destinoLatLng = latLng;
                                _updateMarker('destino', latLng, "Destino: $value", BitmapDescriptor.hueRed);
                                _clearRoute();
                              });
                               _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
                            } else if (mounted) {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo encontrar la ubicación de destino.')));
                            }
                          }
                        },
                      ),
                    ),
                    if (_placeSuggestions.isNotEmpty) _buildSuggestionsList(),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.directions_car),
                      onPressed: _getRoute,
                      label: const Text("Mostrar Ruta"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Theme.of(context).colorScheme.onSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                        textStyle: const TextStyle(fontSize: 16)
                      ),
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
    return Material(
      elevation: 2,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.3), spreadRadius: 1, blurRadius: 3, offset: const Offset(0, 2)),
          ],
        ),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _placeSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = _placeSuggestions[index];
            return ListTile(
              leading: const Icon(Icons.location_pin, color: Colors.grey),
              title: Text(suggestion.structuredFormatting?.mainText ?? suggestion.description ?? ''),
              subtitle: Text(suggestion.structuredFormatting?.secondaryText ?? ''),
              onTap: () {
                FocusScope.of(context).unfocus();
                _getPlaceDetailsAndSet(suggestion, isOrigin: _isOriginFieldFocused);
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    origenController.dispose();
    destinoController.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}