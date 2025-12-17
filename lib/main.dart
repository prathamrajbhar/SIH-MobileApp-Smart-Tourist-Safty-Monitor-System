import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/settings_manager.dart';
import 'services/location_transmission_service.dart';
import 'utils/logger.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize logging and verify configuration
  AppLogger.info('🚀 SafeHorizon Tourist App starting up...');
  
  await _initializeApp();
  
  runApp(const TouristSafetyApp());
}

Future<void> _initializeApp() async {
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Settings Manager
  try {
    await SettingsManager().initialize();
    AppLogger.info('✅ Settings Manager initialized');
  } catch (e) {
    AppLogger.error('❌ Settings Manager initialization failed: $e');
  }
  
  // Store API base URL in shared preferences for background service access
  final prefs = await SharedPreferences.getInstance();
  final apiBaseUrl = dotenv.env['API_BASE_URL']!;
  await prefs.setString('api_base_url', apiBaseUrl);
  
  // Initialize API service and find working server
  final apiService = ApiService();
  await apiService.initializeAuth();
  
  // Initialize Location Transmission Service and send app launch location
  try {
    final locationTransmissionService = LocationTransmissionService();
    await locationTransmissionService.initialize();
    
    // Send immediate location update on app launch
    await locationTransmissionService.sendAppLaunchLocation();
    AppLogger.info('✅ Location Transmission Service initialized and app launch location sent');
  } catch (e) {
    AppLogger.warning('⚠️ Location Transmission Service initialization failed: $e');
  }
  
  // Don't initialize background service on app start to avoid crashes
  // It will be initialized when user logs in and starts tracking
}

class TouristSafetyApp extends StatelessWidget {
  const TouristSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SafeHorizon',
      debugShowCheckedModeBanner: false,
      theme: appTheme, // Use the new comprehensive theme
      home: const AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    
    if (mounted) {
      if (onboardingCompleted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
