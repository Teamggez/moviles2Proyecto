import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  final Map<String, dynamic>? reportData;

  const ReportDetailScreen({
    super.key,
    required this.reportId,
    this.reportData,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;
  GoogleMapController? _mapController;

  final Map<String, Map<String, dynamic>> _reportTypes = {
    'accident': {
      'name': 'Accidente',
      'icon': Icons.car_crash,
      'color': Colors.red,
      'description': 'Accidente de tránsito'
    },
    'fire': {
      'name': 'Incendio',
      'icon': Icons.local_fire_department,
      'color': Colors.orange,
      'description': 'Incendio o emergencia de fuego'
    },
    'roadblock': {
      'name': 'Vía bloqueada',
      'icon': Icons.block,
      'color': Colors.amber,
      'description': 'Bloqueo de vía o tráfico'
    },
    'protest': {
      'name': 'Manifestación',
      'icon': Icons.people,
      'color': Colors.yellow.shade700,
      'description': 'Manifestación o protesta'
    },
    'theft': {
      'name': 'Robo',
      'icon': Icons.money_off,
      'color': Colors.purple,
      'description': 'Robo o hurto'
    },
    'assault': {
      'name': 'Asalto',
      'icon': Icons.personal_injury,
      'color': Colors.deepPurple,
      'description': 'Asalto o agresión'
    },
    'violence': {
      'name': 'Violencia',
      'icon': Icons.front_hand,
      'color': Colors.red.shade800,
      'description': 'Acto de violencia'
    },
    'vandalism': {
      'name': 'Vandalismo',
      'icon': Icons.broken_image,
      'color': Colors.brown,
      'description': 'Vandalismo o daño a propiedad'
    },
  };

  final Map<String, Color> _riskColors = {
    'Bajo': Colors.green,
    'Medio': Colors.orange,
    'Alto': Colors.red,
  };

  @override
  void initState() {
    super.initState();
    if (widget.reportData != null) {
      _reportData = widget.reportData;
      _isLoading = false;
    } else {
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    try {
      // Buscar en la colección Reportes
      QuerySnapshot querySnapshot = await _firestore
          .collection('Reportes')
          .where('id', isEqualTo: widget.reportId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _reportData = querySnapshot.docs.first.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        // Si no se encuentra por ID, buscar por document ID
        DocumentSnapshot docSnapshot = await _firestore
            .collection('Reportes')
            .doc(widget.reportId)
            .get();

        if (docSnapshot.exists) {
          setState(() {
            _reportData = docSnapshot.data() as Map<String, dynamic>;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackBar('Reporte no encontrado');
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Error al cargar el reporte: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _openInMaps() async {
    if (_reportData == null) return;

    final ubicacion = _reportData!['ubicacion'];
    if (ubicacion == null) return;

    final lat = ubicacion['latitud'];
    final lng = ubicacion['longitud'];

    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    
    try {
      await launchUrl(Uri.parse(url));
    } catch (e) {
      _showErrorSnackBar('No se pudo abrir el mapa');
    }
  }

  String _formatDate(dynamic timestamp) {
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Fecha no disponible';
      }
      
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return 'Fecha no disponible';
    }
  }

  String _getTimeAgo(dynamic timestamp) {
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return '';
      }
      
      final now = DateTime.now();
      final difference = now.difference(date);
      
      if (difference.inMinutes < 1) {
        return 'Hace unos segundos';
      } else if (difference.inMinutes < 60) {
        return 'Hace ${difference.inMinutes} minutos';
      } else if (difference.inHours < 24) {
        return 'Hace ${difference.inHours} horas';
      } else {
        return 'Hace ${difference.inDays} días';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildImageGallery() {
  final imagenes = _reportData!['imagenes'] as List<dynamic>?;
  
  if (imagenes == null || imagenes.isEmpty) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.image_outlined, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Imágenes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.image_not_supported_outlined, 
                       color: Colors.grey.shade500, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'No hay imágenes disponibles para este reporte',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.image, color: Colors.purple.shade600),
              const SizedBox(width: 8),
              Text(
                'Imágenes (${imagenes.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 200,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: imagenes.length,
            itemBuilder: (context, index) {
              final imageUrl = imagenes[index] as String;
              return Container(
                width: 160,
                margin: EdgeInsets.only(right: index < imagenes.length - 1 ? 12 : 0),
                child: GestureDetector(
                  onTap: () => _openImageViewer(imagenes.cast<String>(), index),
                  child: Hero(
                    tag: 'image_$index',
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade200,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: Colors.grey.shade500,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Error al cargar',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.touch_app, color: Colors.blue.shade600, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Toca cualquier imagen para verla en pantalla completa',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

void _openImageViewer(List<String> images, int initialIndex) {
  Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => _buildFullScreenImageViewer(images, initialIndex),
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

Widget _buildFullScreenImageViewer(List<String> images, int initialIndex) {
  return StatefulBuilder(
    builder: (context, setState) {
      int currentIndex = initialIndex;
      PageController pageController = PageController(initialPage: initialIndex);
      bool showControls = true;

      return Scaffold(
        backgroundColor: Colors.black,
        appBar: showControls ? AppBar(
          backgroundColor: Colors.black.withOpacity(0.7),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _reportData!['titulo'] ?? 'Reporte',
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${currentIndex + 1} de ${images.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
        ) : null,
        extendBodyBehindAppBar: true,
        body: GestureDetector(
          onTap: () {
            setState(() {
              showControls = !showControls;
            });
          },
          child: Stack(
            children: [
              PageView.builder(
                controller: pageController,
                onPageChanged: (index) {
                  setState(() {
                    currentIndex = index;
                  });
                },
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Center(
                      child: Hero(
                        tag: 'image_$index',
                        child: CachedNetworkImage(
                          imageUrl: images[index],
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, color: Colors.white70, size: 64),
                                SizedBox(height: 16),
                                Text('Error al cargar imagen', style: TextStyle(color: Colors.white70)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Indicadores de página
              if (images.length > 1 && showControls)
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      images.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == currentIndex ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == currentIndex ? Colors.white : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Cargando...'),
          backgroundColor: Colors.indigo[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_reportData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Reporte no encontrado'),
          backgroundColor: Colors.red[700],
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No se pudo cargar la información del reporte',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final reportType = _reportTypes[_reportData!['tipo']] ?? _reportTypes['accident']!;
    final riskLevel = _reportData!['nivelRiesgo'] ?? 'Bajo';
    final ubicacion = _reportData!['ubicacion'];

    return Scaffold(
      appBar: AppBar(
        title: Text(reportType['name']),
        backgroundColor: reportType['color'],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _openInMaps,
            icon: const Icon(Icons.map),
            tooltip: 'Abrir en Maps',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              reportType['color'],
              Colors.grey.shade50,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Card
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: [
                      reportType['color'].withOpacity(0.1),
                      Colors.white,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: reportType['color'],
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: reportType['color'].withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            reportType['icon'],
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _reportData!['titulo'] ?? 'Sin título',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                reportType['description'],
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _riskColors[riskLevel]!.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _riskColors[riskLevel]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning,
                            color: _riskColors[riskLevel],
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Riesgo $riskLevel',
                            style: TextStyle(
                              color: _riskColors[riskLevel],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Descripción
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Descripción',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _reportData!['descripcion'] ?? 'Sin descripción disponible',
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Galería de imágenes
            _buildImageGallery(),

            const SizedBox(height: 16),

            // Información temporal
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.access_time, color: Colors.green.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Información Temporal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'Reportado',
                      _formatDate(_reportData!['fechaCreacion']),
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Hace',
                      _getTimeAgo(_reportData!['fechaCreacion']),
                      Icons.schedule,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Estado',
                      _reportData!['estado'] ?? 'Desconocido',
                      Icons.info_outline,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Mapa de ubicación
            if (ubicacion != null)
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          const Text(
                            'Ubicación',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _openInMaps,
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Abrir en Maps'),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 200,
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              ubicacion['latitud'],
                              ubicacion['longitud'],
                            ),
                            zoom: 16,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('report_location'),
                              position: LatLng(
                                ubicacion['latitud'],
                                ubicacion['longitud'],
                              ),
                              icon: BitmapDescriptor.defaultMarkerWithHue(
                                reportType['color'] == Colors.red
                                    ? BitmapDescriptor.hueRed
                                    : BitmapDescriptor.hueOrange,
                              ),
                              infoWindow: InfoWindow(
                                title: reportType['name'],
                                snippet: _reportData!['titulo'],
                              ),
                            ),
                          },
                          onMapCreated: (GoogleMapController controller) {
                            _mapController = controller;
                          },
                          zoomControlsEnabled: false,
                          mapToolbarEnabled: false,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Row(
                        children: [
                          Icon(Icons.gps_fixed, color: Colors.grey[600], size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Lat: ${ubicacion['latitud'].toStringAsFixed(6)}, '
                              'Lng: ${ubicacion['longitud'].toStringAsFixed(6)}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Información adicional
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.amber.shade600),
                        const SizedBox(width: 8),
                        const Text(
                          'Información Adicional',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(
                      'ID del Reporte',
                      _reportData!['id'] ?? widget.reportId,
                      Icons.fingerprint,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Etapa',
                      _reportData!['etapa'] ?? 'Desconocida',
                      Icons.timeline,
                    ),
                    if (_reportData!['esReportePrueba'] == true) ...[
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        'Tipo',
                        'Reporte de Prueba',
                        Icons.science,
                        valueColor: Colors.orange,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
              fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
