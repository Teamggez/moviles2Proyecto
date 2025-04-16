import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

import 'main.dart';
import 'screen_principal.dart';

@GenerateMocks([FirebaseFirestore, QuerySnapshot, DocumentSnapshot, DocumentReference])
void main() {
  // Setup para inicializar Firebase en pruebas
  setupFirebaseCoreMocks() {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Configurar el mock de Firebase
    MethodChannelFirebase.channel.setMockMethodCallHandler((call) async {
      if (call.method == 'Firebase#initializeApp') {
        return {
          'name': '[DEFAULT]',
          'options': {
            'apiKey': 'test-api-key',
            'appId': 'test-app-id',
            'messagingSenderId': 'test-sender-id',
            'projectId': 'test-project-id',
          },
        };
      }
      return null;
    });
  }

  group('MainApp Tests', () {
    testWidgets('MainApp se renderiza correctamente', (WidgetTester tester) async {
      // Configurar Firebase mock
      setupFirebaseCoreMocks();
      
      // Construir la app
      await tester.pumpWidget(const MainApp());
      
      // Verificar elementos del tema
      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.title, 'Reportes Ciudadanos');
      expect(app.theme?.primaryColor, const Color(0xFF1A56DB));
      expect(app.debugShowCheckedModeBanner, false);
      
      // Verificar que la pantalla de login es la pantalla inicial
      expect(find.byType(LoginScreen), findsOneWidget);
    });
  });

  group('LoginScreen UI Tests', () {
    setUp(() {
      setupFirebaseCoreMocks();
    });
    
    testWidgets('Header se muestra correctamente', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Verificar elementos del header
      expect(find.text('🏙️'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Sistema de Reportes Ciudadanos'), findsOneWidget);
    });

    testWidgets('TabBar muestra las pestañas correctamente', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Verificar pestañas
      expect(find.text('Iniciar Sesión'), findsOneWidget);
      expect(find.text('Registrarse'), findsOneWidget);
    });

    testWidgets('Formulario de login muestra todos los campos', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Verificar campos del formulario
      expect(find.text('Correo Electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Recordar sesión'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'), findsOneWidget);
    });

    testWidgets('Cambio a pestaña de registro funciona', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Cambiar a pestaña de registro
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();
      
      // Verificar campos del formulario de registro
      expect(find.text('Nombre Completo'), findsOneWidget);
      expect(find.text('Correo Electrónico'), findsOneWidget);
      expect(find.text('Contraseña'), findsOneWidget);
      expect(find.text('Confirmar Contraseña'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Crear Cuenta'), findsOneWidget);
    });
  });

  group('Form Validation Tests', () {
    setUp(() {
      setupFirebaseCoreMocks();
    });
    
    testWidgets('Validación de formulario de login', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Intentar login sin datos
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
      await tester.pumpAndSettle();
      
      // Verificar mensajes de error
      expect(find.text('Por favor, ingresa tu correo'), findsOneWidget);
      expect(find.text('Por favor, ingresa tu contraseña'), findsOneWidget);
    });

    testWidgets('Validación de formato de correo en login', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Ingresar correo inválido
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.email_outlined).first, 
        'correo_invalido'
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.lock_outlined).first, 
        'password123'
      );
      
      // Intentar login
      await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar Sesión'));
      await tester.pumpAndSettle();
      
      // Verificar mensaje de error
      expect(find.text('Ingresa un correo válido'), findsOneWidget);
    });

    testWidgets('Validación de formulario de registro', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Cambiar a pestaña de registro
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();
      
      // Intentar registro sin datos
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear Cuenta'));
      await tester.pumpAndSettle();
      
      // Verificar mensajes de error
      expect(find.text('Por favor, ingresa tu nombre'), findsOneWidget);
      expect(find.text('Por favor, ingresa tu correo'), findsOneWidget);
      expect(find.text('Por favor, ingresa una contraseña'), findsOneWidget);
      expect(find.text('Por favor, confirma tu contraseña'), findsOneWidget);
    });

    testWidgets('Validación de contraseñas coincidentes en registro', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Cambiar a pestaña de registro
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();
      
      // Llenar formulario con contraseñas diferentes
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.person_outline), 
        'Usuario Test'
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.email_outlined).last, 
        'test@example.com'
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.lock_outlined).at(1), 
        'password123'
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.lock_outline), 
        'password456'
      );
      
      // Intentar registro
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear Cuenta'));
      await tester.pumpAndSettle();
      
      // Verificar mensaje de error
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    });

    testWidgets('Validación de longitud de contraseña en registro', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Cambiar a pestaña de registro
      await tester.tap(find.text('Registrarse'));
      await tester.pumpAndSettle();
      
      // Llenar formulario con contraseña corta
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.person_outline), 
        'Usuario Test'
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.email_outlined).last, 
        'test@example.com'
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.lock_outlined).at(1), 
        '12345'
      );
      await tester.enterText(
        find.widgetWithIcon(TextFormField, Icons.lock_outline), 
        '12345'
      );
      
      // Intentar registro
      await tester.tap(find.widgetWithText(ElevatedButton, 'Crear Cuenta'));
      await tester.pumpAndSettle();
      
      // Verificar mensaje de error
      expect(find.text('La contraseña debe tener al menos 6 caracteres'), findsOneWidget);
    });
  });

  group('Interactive UI Tests', () {
    setUp(() {
      setupFirebaseCoreMocks();
    });
    
    testWidgets('Toggle de visibilidad de contraseña funciona', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Verificar que la contraseña está oculta inicialmente
      final passwordField = find.widgetWithIcon(TextFormField, Icons.lock_outlined).first;
      expect(tester.widget<TextFormField>(passwordField).obscureText, true);
      
      // Presionar botón de visibilidad
      await tester.tap(find.descendant(
        of: passwordField,
        matching: find.byIcon(Icons.visibility_outlined)
      ));
      await tester.pumpAndSettle();
      
      // Verificar que la contraseña es visible
      expect(tester.widget<TextFormField>(passwordField).obscureText, false);
    });

    testWidgets('Checkbox de recordar sesión funciona', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      
      // Verificar estado inicial
      final checkboxFinder = find.byType(Checkbox);
      expect(tester.widget<Checkbox>(checkboxFinder).value, false);
      
      // Cambiar estado
      await tester.tap(checkboxFinder);
      await tester.pumpAndSettle();
      
      expect(tester.widget<Checkbox>(checkboxFinder).value, true);
    });
  });

  group('Firebase Authentication Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    
    setUp(() {
      setupFirebaseCoreMocks();
      fakeFirestore = FakeFirebaseFirestore();
    });
    
    testWidgets('Login exitoso con credenciales correctas', (WidgetTester tester) async {
      await fakeFirestore.collection('usuarios').add({
        'correo': 'test@example.com',
        'nombre': 'Test User',
        'password': 'password123',
      });
      

    });
    
    testWidgets('Registro exitoso con datos válidos', (WidgetTester tester) async {
    });
  });

  group('Error Handling Tests', () {
    setUp(() {
      setupFirebaseCoreMocks();
    });
    
    testWidgets('Muestra SnackBar con mensaje de error cuando el usuario no existe', (WidgetTester tester) async {
    });
    
    testWidgets('Muestra SnackBar con mensaje de error cuando la contraseña es incorrecta', (WidgetTester tester) async {

    });
  });
}
