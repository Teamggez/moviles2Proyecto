import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/report_detail_screen.dart';

class NotificationService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Clave global para navegación
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Future<void> initialize() async {
    // Solicitar permisos
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Usuario otorgó permisos para notificaciones');
      
      // Configurar handlers
      await _setupNotificationHandlers();
    } else {
      print('Usuario denegó permisos para notificaciones');
    }
  }

  static Future<void> _setupNotificationHandlers() async {
    // Cuando la app está en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Notificación recibida en foreground: ${message.data}');
      _showInAppNotification(message);
    });

    // Cuando la app está en background y se toca la notificación
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notificación tocada desde background: ${message.data}');
      _handleNotificationTap(message);
    });

    // Cuando la app está completamente cerrada y se toca la notificación
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('App abierta desde notificación: ${initialMessage.data}');
      // Esperar un poco para que la app se inicialice completamente
      Future.delayed(const Duration(seconds: 2), () {
        _handleNotificationTap(initialMessage);
      });
    }
  }

  static void _showInAppNotification(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.notification?.title ?? 'Nueva Alerta',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(message.notification?.body ?? 'Tienes un nuevo reporte cerca'),
            ],
          ),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () => _handleNotificationTap(message),
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static Future<void> _handleNotificationTap(RemoteMessage message) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    try {
      // Extraer el ID del reporte desde los datos de la notificación
      String? reportId = message.data['report_id'] ?? message.data['reporte_id'];
      
      if (reportId != null) {
        // Buscar el reporte en Firestore
        DocumentSnapshot reportDoc = await _firestore
            .collection('reportes')
            .doc(reportId)
            .get();

        if (reportDoc.exists) {
          // Navegar a la pantalla de detalle del reporte
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReportDetailsScreen(
                reportId: reportId,
                reportData: reportDoc.data() as Map<String, dynamic>,
              ),
            ),
          );
        } else {
          _showErrorSnackBar(context, 'No se pudo encontrar el reporte');
        }
      } else {
        _showErrorSnackBar(context, 'Información de reporte no disponible');
      }
    } catch (e) {
      print('Error al manejar notificación: $e');
      _showErrorSnackBar(context, 'Error al abrir el reporte');
    }
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<String?> getToken() async {
    try {
      return await _firebaseMessaging.getToken();
    } catch (e) {
      print('Error obteniendo token FCM: $e');
      return null;
    }
  }
}
