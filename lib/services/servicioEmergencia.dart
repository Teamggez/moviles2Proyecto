// services/servicioEmergencia.dart

import 'package:flutter/material.dart';

class EmergencyService {
  static List<Map<String, dynamic>> getEmergencyContacts() {
    return [
      {
        'name': 'Violencia familiar y sexual (MIMP)',
        'phone': '100',
        'icon': Icons.support_agent,
        'isPersonal': false // Flag to distinguish
      },
      {
        'name': 'Policía Nacional del Perú',
        'phone': '105',
        'icon': Icons.local_police,
        'isPersonal': false
      },
      {
        'name': 'SAMU - Atención Médica Móvil',
        'phone': '106',
        'icon': Icons.medical_services,
        'isPersonal': false
      },
      {
        'name': 'Policía de Carreteras',
        'phone': '110',
        'icon': Icons.directions_car,
        'isPersonal': false
      },
      {
        'name': 'MINSA - Consultas sobre Coronavirus',
        'phone': '113',
        'icon': Icons.coronavirus,
        'isPersonal': false
      },
      {
        'name': 'Defensa Civil',
        'phone': '115',
        'icon': Icons.security,
        'isPersonal': false
      },
      {
        'name': 'Bomberos Voluntarios del Perú',
        'phone': '116',
        'icon': Icons.local_fire_department,
        'isPersonal': false
      },
      {
        'name': 'EsSalud - Atención Médica Móvil',
        'phone': '117',
        'icon': Icons.emergency,
        'isPersonal': false
      },
      {
        'name': 'MTC - Mensajes de voz ante emergencias',
        'phone': '119',
        'icon': Icons.voicemail,
        'isPersonal': false
      },
      {
        'name': 'Hospital Hipólito Unanue',
        'phone': '(052) 242121',
        'icon': Icons.local_hospital,
        'isPersonal': false
      },
      {
        'name': 'Seguridad Ciudadana – MPT',
        'phone': '(052) 580310',
        'icon': Icons.verified_user,
        'isPersonal': false
      },
      {
        'name': 'Ricardo (Contacto Personal)',
        'phone': '961256178',
        'icon': Icons.person,
        'isPersonal': true // Flag to identify personal contact
      },
    ];
  }
}