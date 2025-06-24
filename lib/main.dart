import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'services/location_service.dart';
import 'firebase_options.dart';
import 'screen_principal.dart';
import '/screens/report_detail_screen.dart';
import 'dart:convert';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AlertaTacna',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF1E3A8A),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: const Color(0xFF1E3A8A),
          secondary: const Color(0xFF3B82F6),
        ),
        fontFamily: 'SF Pro Display',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.w700),
          displayMedium: TextStyle(fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontWeight: FontWeight.w400),
        ),
      ),
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F172A),
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
              ),
            ),
          );
        }
        
        if (snapshot.hasData) {
          return const ScreenPrincipal();
        }
        
        return const LoginScreen();
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _backgroundAnimationController;
  late AnimationController _contentAnimationController;
  late AnimationController _particleAnimationController;
  
  late Animation<double> _backgroundAnimation;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _particleAnimation;
  
  final GlobalKey<FormState> _loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _registerFormKey = GlobalKey<FormState>();

  // Controladores de texto
  final TextEditingController _emailLoginController = TextEditingController();
  final TextEditingController _passwordLoginController = TextEditingController();
  final TextEditingController _nameRegisterController = TextEditingController();
  final TextEditingController _emailRegisterController = TextEditingController();
  final TextEditingController _passwordRegisterController = TextEditingController();

  // Estados
  bool _isLoggingIn = false;
  bool _isRegistering = false;
  bool _isGoogleSignIn = false;

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final LocationService _locationService = LocationService();

  // Contenido dinámico
  final List<Map<String, dynamic>> _heroContent = [
    {
      'icon': Icons.shield_outlined,
      'title': 'Seguridad Inteligente',
      'subtitle': 'Protección comunitaria con tecnología avanzada de alertas en tiempo real.',
      'gradient': [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
    },
    {
      'icon': Icons.location_on_outlined,
      'title': 'Alertas de Proximidad',
      'subtitle': 'Recibe notificaciones automáticas cuando te acerques a zonas de riesgo.',
      'gradient': [Color(0xFF7C3AED), Color(0xFFA855F7)],
    },
    {
      'icon': Icons.people_outline,
      'title': 'Red Colaborativa',
      'subtitle': 'Únete a tu comunidad para crear un entorno más seguro para todos.',
      'gradient': [Color(0xFF059669), Color(0xFF10B981)],
    },
  ];

  int _currentContentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupFCM();
    _startContentRotation();
  }

  void _initializeAnimations() {
    _tabController = TabController(length: 2, vsync: this);
    
    // Animación de fondo
    _backgroundAnimationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );
    
    // Animación de contenido
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Animación de partículas
    _particleAnimationController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    );
    
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundAnimationController,
      curve: Curves.linear,
    ));
    
    _fadeInAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentAnimationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentAnimationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _contentAnimationController,
      curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
    ));
    
    _particleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_particleAnimationController);
    
    // Iniciar animaciones
    _backgroundAnimationController.repeat();
    _particleAnimationController.repeat();
    _contentAnimationController.forward();
  }

  void _startContentRotation() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _currentContentIndex = (_currentContentIndex + 1) % _heroContent.length;
        });
        _startContentRotation();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _backgroundAnimationController.dispose();
    _contentAnimationController.dispose();
    _particleAnimationController.dispose();
    _emailLoginController.dispose();
    _passwordLoginController.dispose();
    _nameRegisterController.dispose();
    _emailRegisterController.dispose();
    _passwordRegisterController.dispose();
    super.dispose();
  }

  // Funciones de autenticación
  Future<void> _login() async {
    if (_loginFormKey.currentState!.validate()) {
      setState(() => _isLoggingIn = true);

      try {
        String email = _emailLoginController.text.trim();
        String password = _passwordLoginController.text.trim();

        QuerySnapshot querySnapshot = await _firestore
            .collection('usuarios')
            .where('correo', isEqualTo: email)
            .where('password', isEqualTo: password)
            .get();

        if (querySnapshot.docs.isNotEmpty && mounted) {
          await _startUserServices(email);
        } else if (mounted) {
          _showErrorSnackBar('Credenciales incorrectas');
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Error al iniciar sesión: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoggingIn = false);
        }
      }
    }
  }

  Future<void> _register() async {
    if (_registerFormKey.currentState!.validate()) {
      setState(() => _isRegistering = true);

      try {
        String name = _nameRegisterController.text.trim();
        String email = _emailRegisterController.text.trim();
        String password = _passwordRegisterController.text.trim();

        QuerySnapshot existingUser = await _firestore
            .collection('usuarios')
            .where('correo', isEqualTo: email)
            .get();

        if (existingUser.docs.isNotEmpty) {
          if (mounted) {
            _showErrorSnackBar('El usuario ya existe');
          }
          return;
        }

        await _firestore.collection('usuarios').doc(email).set({
          'nombre': name,
          'correo': email,
          'password': password,
          'notificacionesActivas': true,
          'radioAlerta': 500,
          'sensibilidad': 'Medio',
          'fechaCreacion': FieldValue.serverTimestamp(),
          'ultimoAcceso': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _showSuccessSnackBar('Usuario registrado exitosamente');
          _clearRegisterForm();
          _tabController.animateTo(0);
        }
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Error al registrar usuario: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isRegistering = false);
        }
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleSignIn = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        if (mounted) setState(() => _isGoogleSignIn = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await _createOrUpdateUserDocument(userCredential.user!);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error al iniciar sesión con Google');
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleSignIn = false);
      }
    }
  }

  Future<void> _createOrUpdateUserDocument(User user) async {
    final userDoc = _firestore.collection('usuarios').doc(user.email);
    final docSnapshot = await userDoc.get();
    
    if (!docSnapshot.exists) {
      await userDoc.set({
        'correo': user.email,
        'nombre': user.displayName ?? 'Usuario',
        'notificacionesActivas': true,
        'radioAlerta': 500,
        'sensibilidad': 'Medio',
        'fechaCreacion': FieldValue.serverTimestamp(),
        'ultimoAcceso': FieldValue.serverTimestamp(),
        'loginMethod': 'google',
      });
    } else {
      await userDoc.update({
        'ultimoAcceso': FieldValue.serverTimestamp(),
      });
    }
    await _startUserServices(user.email!);
  }

  // Configuración FCM
  Future<void> _setupFCM() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _setupLocalNotifications();
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
        FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
      }
    } catch (e) {
      debugPrint('FCM: Error configurando: $e');
    }
  }

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final data = json.decode(response.payload!);
          final reportId = data['report_id'];
          if (reportId != null) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ReportDetailScreen(
                  reportId: reportId,
                  reportData: data,
                ),
              ),
            );
          }
        }
      },
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (message.notification != null) {
      _showLocalNotification(message);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (message.data['type'] == 'proximity_alert') {
      final reportId = message.data['report_id'];
      if (reportId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReportDetailScreen(
              reportId: reportId,
              reportData: {
                'id': message.data['report_id'],
                'tipo': message.data['report_type'],
                'titulo': message.data['report_title'],
                'nivelRiesgo': message.data['risk_level'],
                'ubicacion': {
                  'latitud': double.tryParse(message.data['latitude'] ?? '0') ?? 0,
                  'longitud': double.tryParse(message.data['longitude'] ?? '0') ?? 0,
                },
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'proximity_alerts',
          'Alertas de Proximidad',
          channelDescription: 'Notificaciones de reportes cercanos',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: DarwinNotificationDetails(),
    );

    final payload = json.encode({
      'report_id': message.data['report_id'],
      'report_type': message.data['report_type'],
      'report_title': message.data['report_title'],
      'risk_level': message.data['risk_level'],
      'latitude': message.data['latitude'],
      'longitude': message.data['longitude'],
    });

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      message.notification?.title ?? 'Alerta de Proximidad',
      message.notification?.body ?? 'Hay un reporte cerca de tu ubicación',
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> _saveUserFCMToken(String userEmail) async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _firestore.collection('usuarios').doc(userEmail).update({
          'fcmToken': token,
          'tokenActualizacion': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('FCM: Error guardando token: $e');
    }
  }

  Future<void> _startUserServices(String userEmail) async {
    await _saveUserFCMToken(userEmail);
    await _locationService.startLocationTracking();
  }

  void _clearRegisterForm() {
    _nameRegisterController.clear();
    _emailRegisterController.clear();
    _passwordRegisterController.clear();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentContent = _heroContent[_currentContentIndex];
    
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _backgroundAnimation,
          _particleAnimation,
        ]),
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF0F172A),
                    const Color(0xFF1E293B),
                    _backgroundAnimation.value * 0.5,
                  )!,
                  Color.lerp(
                    const Color(0xFF1E293B),
                    const Color(0xFF334155),
                    _backgroundAnimation.value * 0.3,
                  )!,
                  Color.lerp(
                    currentContent['gradient'][0],
                    currentContent['gradient'][1],
                    _backgroundAnimation.value * 0.2,
                  )!,
                ],
                stops: [
                  0.0,
                  0.5 + (_backgroundAnimation.value * 0.3),
                  1.0,
                ],
              ),
            ),
            child: Stack(
              children: [
                // Partículas animadas de fondo
                ...List.generate(20, (index) {
                  final offset = Offset(
                    (index * 50.0) % MediaQuery.of(context).size.width,
                    (index * 80.0) % MediaQuery.of(context).size.height,
                  );
                  return Positioned(
                    left: offset.dx + (_particleAnimation.value * 100) - 50,
                    top: offset.dy + (_particleAnimation.value * 200) - 100,
                    child: Opacity(
                      opacity: 0.1 + (_particleAnimation.value * 0.1),
                      child: Container(
                        width: 4 + (index % 3) * 2,
                        height: 4 + (index % 3) * 2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  );
                }),
                
                // Contenido principal
                SafeArea(
                  child: Column(
                    children: [
                      // Sección superior - Hero (más pequeña)
                      Expanded(
                        flex: 4,
                        child: _buildHeroSection(currentContent),
                      ),
                      
                      // Sección inferior - Formularios (con transparencia)
                      Expanded(
                        flex: 7,
                        child: _buildFormSection(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroSection(Map<String, dynamic> content) {
    return FadeTransition(
      opacity: _fadeInAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo animado
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 800),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    key: ValueKey(_currentContentIndex),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: content['gradient'],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: content['gradient'][0].withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      content['icon'],
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Título animado
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Text(
                    content['title'],
                    key: ValueKey('${_currentContentIndex}_title'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Subtítulo animado
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 600),
                  child: Text(
                    content['subtitle'],
                    key: ValueKey('${_currentContentIndex}_subtitle'),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade300,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Indicadores de contenido
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_heroContent.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: index == _currentContentIndex ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: index == _currentContentIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      decoration: BoxDecoration(
        // Fondo semi-transparente para que se vea la animación
        color: const Color(0xFF0F172A).withOpacity(0.85),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tabs
          Container(
            margin: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey.shade400,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              tabs: const [
                Tab(text: 'Iniciar Sesión'),
                Tab(text: 'Registrarse'),
              ],
            ),
          ),

          // Contenido de tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLoginForm(),
                _buildRegisterForm(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          children: [
            // Google Sign-In Button
            _buildGoogleSignInButton(),
            
            const SizedBox(height: 24),
            
            // Divider
            _buildDivider(),
            
            const SizedBox(height: 24),
            
            // Email Field
            _buildTextField(
              controller: _emailLoginController,
              hintText: 'tu@email.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingresa tu correo';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Password Field
            _buildTextField(
              controller: _passwordLoginController,
              hintText: 'Tu contraseña',
              icon: Icons.lock_outline,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingresa tu contraseña';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 32),
            
            // Login Button
            _buildPrimaryButton(
              text: 'Iniciar Sesión',
              isLoading: _isLoggingIn,
              onPressed: _login,
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          children: [
            // Name Field
            _buildTextField(
              controller: _nameRegisterController,
              hintText: 'Tu nombre completo',
              icon: Icons.person_outline,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingresa tu nombre';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Email Field
            _buildTextField(
              controller: _emailRegisterController,
              hintText: 'tu@email.com',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingresa tu correo';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Password Field
            _buildTextField(
              controller: _passwordRegisterController,
              hintText: 'Crea una contraseña segura',
              icon: Icons.lock_outline,
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingresa una contraseña';
                }
                if (value.length < 6) {
                  return 'La contraseña debe tener al menos 6 caracteres';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 32),
            
            // Register Button
            _buildPrimaryButton(
              text: 'Crear Cuenta',
              isLoading: _isRegistering,
              onPressed: _register,
            ),
            
            const SizedBox(height: 16),
            
            // Info Card
            _buildInfoCard(),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4285F4), Color(0xFF1976D2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4285F4).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isGoogleSignIn ? null : _signInWithGoogle,
        icon: _isGoogleSignIn
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Image.network(
                'https://developers.google.com/identity/images/g-logo.png',
                width: 24,
                height: 24,
              ),
        label: Text(
          _isGoogleSignIn ? 'Iniciando sesión...' : 'Continuar con Google',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        prefixIcon: Icon(icon, color: Colors.grey.shade500),
        filled: true,
        fillColor: const Color(0xFF1E293B).withOpacity(0.7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade800.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        contentPadding: const EdgeInsets.all(20),
      ),
      validator: validator,
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade700.withOpacity(0.5))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'o continúa con correo',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade700.withOpacity(0.5))),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF3B82F6).withOpacity(0.1),
            const Color(0xFF1D4ED8).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: const Color(0xFF3B82F6),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Al registrarte, se activarán automáticamente las alertas de proximidad.',
              style: TextStyle(
                color: Colors.blue.shade200,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
