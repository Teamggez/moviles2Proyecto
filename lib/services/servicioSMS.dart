import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsLogic {
  Future<void> sendSMS(String phoneNumber, String message, BuildContext context) async {
    final String sanitizedPhoneNumber = phoneNumber.replaceAll(RegExp(r'[()\s]'), '');
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: sanitizedPhoneNumber,
      queryParameters: {'body': message},
    );
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo abrir la app de SMS para $phoneNumber'),
              backgroundColor: Colors.red,
            ),
          );
        }
        debugPrint('No se pudo lanzar $smsUri');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al intentar enviar SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Error al lanzar $smsUri: $e');
    }
  }
}