import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Constantes para SharedPreferences
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userEmailKey = 'user_email';
  static const String _loginMethodKey = 'login_method';

  // Stream controller para notificar cambios de estado
  static final _authStateController = StreamController<bool>.broadcast();

  // Stream para escuchar cambios de autenticación (personalizado)
  static Stream<bool> get authStateChanges => _authStateController.stream;

  // Usuario actual
  static User? get currentUser => _auth.currentUser;

  // Login con Google
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      // Limpiar cualquier sesión anterior
      await _googleSignIn.signOut();
      
      // Iniciar el proceso de autenticación
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // El usuario canceló el login
        return null;
      }

      // Obtener los detalles de autenticación
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Crear credencial para Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Autenticar con Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Guardar información del usuario en Firestore
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await saveGoogleLogin(userCredential.user!.email!);
      }

      return userCredential;
    } catch (e) {
      print('Error en login con Google: $e');
      rethrow;
    }
  }

  // Login con email y contraseña
  static Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Guardar información del usuario en Firestore
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await saveCredentialLogin(email);
      }

      return userCredential;
    } catch (e) {
      print('Error en login con email: $e');
      rethrow;
    }
  }

  // Agregar el método signInAnonymously después del método signInWithEmailAndPassword

  static Future<UserCredential?> signInAnonymously() async {
    try {
      final UserCredential userCredential = await _auth.signInAnonymously();
      return userCredential;
    } catch (e) {
      print('Error en login anónimo: $e');
      rethrow;
    }
  }

  // Verificar si el usuario está logueado (SharedPreferences)
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // Obtener email del usuario actual
  static Future<String?> getCurrentUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userEmailKey);
  }

  // Obtener método de login
  static Future<String?> getLoginMethod() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_loginMethodKey);
  }

  // Guardar estado de login con credenciales
  static Future<void> saveCredentialLogin(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_loginMethodKey, 'credentials');
    _authStateController.add(true);
  }

  // Guardar estado de login con Google
  static Future<void> saveGoogleLogin(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userEmailKey, email);
    await prefs.setString(_loginMethodKey, 'google');
    _authStateController.add(true);
  }

  // Registro con email y contraseña
  static Future<UserCredential?> createUserWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      // Guardar información del usuario en Firestore
      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await saveCredentialLogin(email);
      }

      return userCredential;
    } catch (e) {
      print('Error en registro: $e');
      rethrow;
    }
  }

  // Guardar usuario en Firestore
  static Future<void> _saveUserToFirestore(User user) async {
    try {
      await _firestore.collection('usuarios').doc(user.email).set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName ?? '',
        'photoURL': user.photoURL ?? '',
        'lastLogin': FieldValue.serverTimestamp(),
        'notificacionesActivas': true,
        'radioAlerta': 500,
        'sensibilidad': 'Medio',
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error guardando usuario en Firestore: $e');
    }
  }

// Cerrar sesión
static Future<void> signOut() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final loginMethod = prefs.getString(_loginMethodKey);
    
    // Cerrar sesión de Firebase Auth
    await _auth.signOut();
    
    // Si fue login con Google, cerrar sesión de Google también
    if (loginMethod == 'google') {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print('Error cerrando sesión de Google: $e');
        // No lanzar error aquí, continuar con el logout
      }
    }
    
    // Limpiar datos locales
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_loginMethodKey);
    
    _authStateController.add(false);
    
    print('Sesión cerrada exitosamente');
  } catch (e) {
    print('Error cerrando sesión: $e');
    // Aún así limpiar los datos locales
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_loginMethodKey);
    _authStateController.add(false);
    rethrow;
  }
}

  // Obtener información del usuario actual
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      final email = await getCurrentUserEmail();
      if (email == null) return null;

      final DocumentSnapshot userDoc = await _firestore
          .collection('usuarios')
          .doc(email)
          .get();

      if (userDoc.exists) {
        return userDoc.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error obteniendo datos del usuario: $e');
      return null;
    }
  }

  // Verificar si el usuario está autenticado
  static bool isUserLoggedIn() {
    return _auth.currentUser != null;
  }

  // Manejar errores de autenticación
  static String getAuthErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No se encontró una cuenta con este email.';
        case 'wrong-password':
          return 'Contraseña incorrecta.';
        case 'email-already-in-use':
          return 'Ya existe una cuenta con este email.';
        case 'weak-password':
          return 'La contraseña es muy débil.';
        case 'invalid-email':
          return 'El formato del email es inválido.';
        case 'user-disabled':
          return 'Esta cuenta ha sido deshabilitada.';
        case 'too-many-requests':
          return 'Demasiados intentos fallidos. Intenta más tarde.';
        case 'network-request-failed':
          return 'Error de conexión. Verifica tu internet.';
        default:
          return 'Error de autenticación: ${error.message}';
      }
    }
    return 'Error desconocido: $error';
  }

  static void dispose() {
    _authStateController.close();
  }
}
