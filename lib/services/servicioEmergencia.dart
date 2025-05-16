import 'dart:math';

import 'package:flutter/material.dart';

class EmergencyService {
  // Singleton pattern
  static final EmergencyService _instance = EmergencyService._internal();
  factory EmergencyService() => _instance;
  EmergencyService._internal();

  final List<Map<String, dynamic>> _emergencyContacts = [
    {
      'id': 1,
      'name': 'Violencia familiar y sexual (MIMP)',
      'phone': '100',
      'icon': Icons.support_agent,
      'isPersonal': false
    },
    {
      'id': 2,
      'name': 'Policía Nacional del Perú',
      'phone': '105',
      'icon': Icons.local_police,
      'isPersonal': false
    },
    {
      'id': 3,
      'name': 'SAMU - Atención Médica Móvil',
      'phone': '106',
      'icon': Icons.medical_services,
      'isPersonal': false
    },
    {
      'id': 4,
      'name': 'Policía de Carreteras',
      'phone': '110',
      'icon': Icons.directions_car,
      'isPersonal': false
    },
    {
      'id': 5,
      'name': 'MINSA - Consultas sobre Coronavirus',
      'phone': '113',
      'icon': Icons.coronavirus,
      'isPersonal': false
    },
    {
      'id': 6,
      'name': 'Defensa Civil',
      'phone': '115',
      'icon': Icons.security,
      'isPersonal': false
    },
    {
      'id': 7,
      'name': 'Bomberos Voluntarios del Perú',
      'phone': '116',
      'icon': Icons.local_fire_department,
      'isPersonal': false
    },
    {
      'id': 8,
      'name': 'EsSalud - Atención Médica Móvil',
      'phone': '117',
      'icon': Icons.emergency,
      'isPersonal': false
    },
    {
      'id': 9,
      'name': 'MTC - Mensajes de voz ante emergencias',
      'phone': '119',
      'icon': Icons.voicemail,
      'isPersonal': false
    },
    {
      'id': 10,
      'name': 'Hospital Hipólito Unanue',
      'phone': '(052) 242121',
      'icon': Icons.local_hospital,
      'isPersonal': false
    },
    {
      'id': 11,
      'name': 'Seguridad Ciudadana – MPT',
      'phone': '(052) 580310',
      'icon': Icons.verified_user,
      'isPersonal': false
    },
    {
      'id': 12,
      'name': 'Ricardo (Contacto Personal)',
      'phone': '961256178',
      'icon': Icons.person,
      'isPersonal': true
    },
  ];

  // Inicializa nextId basado en la lista existente
  late int nextId = _calculateNextId();

  // Calcula el siguiente ID disponible
  int _calculateNextId() {
    if (_emergencyContacts.isEmpty) return 1;
    final maxId =
        _emergencyContacts.map((contact) => contact['id'] as int).reduce(max);
    return maxId + 1;
  }

  List<Map<String, dynamic>> getEmergencyContacts({bool copy = true}) {
    return copy ? List.from(_emergencyContacts) : _emergencyContacts;
  }

  void deleteEmergencyContactById(int id) {
    final index =
        _emergencyContacts.indexWhere((contact) => contact['id'] == id);
    if (index != -1) {
      _emergencyContacts.removeAt(index);
    }
    nextId = _calculateNextId();
  }

  void updateEmergencyContact({
    required int id,
    required String name,
    required String phone,
    required IconData icon,
    required bool isPersonal,
  }) {
    final contact = _emergencyContacts.firstWhere((c) => c['id'] == id);
    contact['name'] = name;
    contact['phone'] = phone;
    contact['icon'] = icon;
    contact['isPersonal'] = isPersonal;
  }

  void addEmergencyContact({
    required String name,
    required String phone,
    IconData? icon,
    bool isPersonal = true,
  }) {
    _emergencyContacts.add({
      'id': nextId,
      'name': name,
      'phone': phone,
      'icon': icon ?? Icons.person,
      'isPersonal': isPersonal,
    });
    nextId++;
  }

  void reorderEmergencyContact(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;
    final contact = _emergencyContacts.removeAt(oldIndex);
    _emergencyContacts.insert(newIndex, contact);
    // Aquí debes actualizar el backend con el nuevo orden
    _updateBackendOrder();
  }

  void _updateBackendOrder() async {
    final List orderedIds = _emergencyContacts.map((c) => c['id']).toList();
    // Llama a tu API para guardar el nuevo orden usando orderedIds
  }
}
