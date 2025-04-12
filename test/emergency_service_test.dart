import 'package:flutter_test/flutter_test.dart';
import 'package:moviles2Proyecto/services/emergency_service.dart';
void main() {
  test('getEmergencyContacts devuelve 4 contactos con nombre y teléfono', () {
    final contacts = EmergencyService.getEmergencyContacts();

    expect(contacts.length, 4);
    expect(contacts[0]['name'], 'Policía');
    expect(contacts[0]['phone'], '911');
    expect(contacts[1]['name'], 'Bomberos');
    expect(contacts[1]['phone'], '912');
    expect(contacts[2]['name'], 'Ambulancia');
    expect(contacts[2]['phone'], '913');
    expect(contacts[3]['name'], 'Protección Civil');
    expect(contacts[3]['phone'], '914');
  });
}
