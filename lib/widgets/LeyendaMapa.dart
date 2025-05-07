// widgets/LeyendaMapa.dart
import 'package:flutter/material.dart';

class LeyendaMapa extends StatefulWidget {
  final VoidCallback onClose;

  const LeyendaMapa({
    super.key,
    required this.onClose,
  });

  @override
  State<LeyendaMapa> createState() => _LeyendaMapaState();
}

class _LeyendaMapaState extends State<LeyendaMapa>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
            parent: _animationController, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _cerrarLeyenda() {
    _animationController.reverse().then((_) {
      widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              elevation: 10,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Leyenda del Mapa',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close,
                              size: 22, color: Colors.black54),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: _cerrarLeyenda,
                        ),
                      ],
                    ),
                    const Divider(height: 24, thickness: 1),
                    const Text(
                      'Niveles de Riesgo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildLeyendaItem(
                      color: Colors.red.withOpacity(0.6),
                      texto: 'Zona Peligrosa',
                      descripcion:
                          'Alto riesgo de incidentes. Se recomienda evitar estas áreas, especialmente durante la noche.',
                    ),
                    const SizedBox(height: 16),
                    _buildLeyendaItem(
                      color: Colors.orange.withOpacity(0.6),
                      texto: 'Zona de Riesgo Medio',
                      descripcion:
                          'Precaución recomendada. Manténgase alerta y evite mostrar objetos de valor.',
                    ),
                    const SizedBox(height: 16),
                    _buildLeyendaItem(
                      color: Colors.green.withOpacity(0.6),
                      texto: 'Zona Segura',
                      descripcion:
                          'Bajo riesgo de incidentes. Áreas generalmente seguras con buena vigilancia.',
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 24, thickness: 1),
                    const Text(
                      'Información Adicional',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      icon: Icons.access_time,
                      texto: 'Datos actualizados cada 24 horas',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoItem(
                      icon: Icons.people,
                      texto: 'Basado en reportes de usuarios y datos oficiales',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoItem(
                      icon: Icons.info_outline,
                      texto: 'Toque en el mapa para ver detalles específicos',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cerrarLeyenda,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Entendido'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeyendaItem({
    required Color color,
    required String texto,
    required String descripcion,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: color.withOpacity(0.8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                texto,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                descripcion,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String texto,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.blue.shade700,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}
