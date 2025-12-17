import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Settings Manager - Centralized app settings management
/// Handles all user preferences and syncs across the app
/// Thread-safe implementation with proper initialization handling
class SettingsManager {
  static final SettingsManager _instance = SettingsManager._internal();
  factory SettingsManager() => _instance;
  SettingsManager._internal();

  // SharedPreferences instance with thread safety
  SharedPreferences? _prefs;
  bool _isInitializing = false;
  bool _isInitialized = false;

  // Settings Keys
  static const String keyLocationTracking = 'location_tracking';
  static const String keyPushNotifications = 'push_notifications';
  static const String keySosAlerts = 'sos_alerts';
  static const String keySafetyAlerts = 'safety_alerts';
  static const String keyProximityAlerts = 'proximity_alerts';
  static const String keyGeofenceAlerts = 'geofence_alerts';
  static const String keyBatteryOptimization = 'battery_optimization';
  static const String keyUpdateInterval = 'update_interval';
  static const String keyLocationUpdateInterval = 'location_update_interval';
  static const String keyNotificationSound = 'notification_sound';
  static const String keyNotificationVibration = 'notification_vibration';
  static const String keyAutoStartTracking = 'auto_start_tracking';
  static const String keyDarkMode = 'dark_mode';
  static const String keyLanguage = 'language';
  static const String keyMapType = 'map_type';
  static const String keyProximityRadius = 'proximity_radius';
  static const String keyShowResolvedAlerts = 'show_resolved_alerts';
  static const String keyOfflineMode = 'offline_mode';

  // Default Values
  static const bool defaultLocationTracking = true;
  static const bool defaultPushNotifications = true;
  static const bool defaultSosAlerts = true;
  static const bool defaultSafetyAlerts = true;
  static const bool defaultProximityAlerts = true;
  static const bool defaultGeofenceAlerts = true;
  static const bool defaultBatteryOptimization = false;
  static const String defaultUpdateInterval = '10';
  static const int defaultLocationUpdateInterval = 15; // minutes
  static const bool defaultNotificationSound = true;
  static const bool defaultNotificationVibration = true;
  static const bool defaultAutoStartTracking = true;
  static const bool defaultDarkMode = false;
  static const String defaultLanguage = 'en';
  static const String defaultMapType = 'standard';
  static const int defaultProximityRadius = 5;
  static const bool defaultShowResolvedAlerts = false;
  static const bool defaultOfflineMode = false;

  /// Initialize settings manager with thread safety
  Future<void> initialize() async {
    if (_isInitialized) {
      AppLogger.info('Settings Manager already initialized');
      return;
    }
    
    if (_isInitializing) {
      // Wait for existing initialization to complete
      while (_isInitializing && !_isInitialized) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return;
    }
    
    _isInitializing = true;
    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      AppLogger.info('✅ Settings Manager initialized');
    } catch (e) {
      AppLogger.error('❌ Settings Manager initialization failed: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// Get SharedPreferences instance with automatic initialization
  Future<SharedPreferences> get safePrefs async {
    if (!_isInitialized) {
      await initialize();
    }
    return _prefs!;
  }

  /// Get SharedPreferences instance (legacy method - synchronous)
  /// @deprecated Use safePrefs for better thread safety
  SharedPreferences get prefs {
    if (_prefs == null) {
      throw Exception('SettingsManager not initialized. Call initialize() first or use safePrefs.');
    }
    return _prefs!;
  }

  // ========== LOCATION & TRACKING ==========

  bool get locationTracking => 
      prefs.getBool(keyLocationTracking) ?? defaultLocationTracking;
  
  Future<void> setLocationTracking(bool value) async {
    await prefs.setBool(keyLocationTracking, value);
    AppLogger.info('📍 Location tracking: ${value ? "ON" : "OFF"}');
  }

  String get updateInterval => 
      prefs.getString(keyUpdateInterval) ?? defaultUpdateInterval;
  
  Future<void> setUpdateInterval(String value) async {
    await prefs.setString(keyUpdateInterval, value);
    AppLogger.info('⏱️ Update interval: ${value}s');
  }

  int get updateIntervalSeconds => int.tryParse(updateInterval) ?? 10;

  int get locationUpdateInterval => 
      prefs.getInt(keyLocationUpdateInterval) ?? defaultLocationUpdateInterval;
  
  Future<void> setLocationUpdateInterval(int minutes) async {
    await prefs.setInt(keyLocationUpdateInterval, minutes);
    AppLogger.info('📍 Location update interval: ${minutes} minutes');
  }

  bool get batteryOptimization => 
      prefs.getBool(keyBatteryOptimization) ?? defaultBatteryOptimization;
  
  Future<void> setBatteryOptimization(bool value) async {
    await prefs.setBool(keyBatteryOptimization, value);
    AppLogger.info('🔋 Battery optimization: ${value ? "ON" : "OFF"}');
  }

  bool get autoStartTracking => 
      prefs.getBool(keyAutoStartTracking) ?? defaultAutoStartTracking;
  
  Future<void> setAutoStartTracking(bool value) async {
    await prefs.setBool(keyAutoStartTracking, value);
    AppLogger.info('🚀 Auto-start tracking: ${value ? "ON" : "OFF"}');
  }

  // ========== NOTIFICATIONS ==========

  bool get pushNotifications => 
      prefs.getBool(keyPushNotifications) ?? defaultPushNotifications;
  
  Future<void> setPushNotifications(bool value) async {
    await prefs.setBool(keyPushNotifications, value);
    AppLogger.info('🔔 Push notifications: ${value ? "ON" : "OFF"}');
  }

  bool get sosAlerts => 
      prefs.getBool(keySosAlerts) ?? defaultSosAlerts;
  
  Future<void> setSosAlerts(bool value) async {
    await prefs.setBool(keySosAlerts, value);
    AppLogger.info('🚨 SOS alerts: ${value ? "ON" : "OFF"}');
  }

  bool get safetyAlerts => 
      prefs.getBool(keySafetyAlerts) ?? defaultSafetyAlerts;
  
  Future<void> setSafetyAlerts(bool value) async {
    await prefs.setBool(keySafetyAlerts, value);
    AppLogger.info('⚠️ Safety alerts: ${value ? "ON" : "OFF"}');
  }

  bool get proximityAlerts => 
      prefs.getBool(keyProximityAlerts) ?? defaultProximityAlerts;
  
  Future<void> setProximityAlerts(bool value) async {
    await prefs.setBool(keyProximityAlerts, value);
    AppLogger.info('📍 Proximity alerts: ${value ? "ON" : "OFF"}');
  }

  bool get geofenceAlerts => 
      prefs.getBool(keyGeofenceAlerts) ?? defaultGeofenceAlerts;
  
  Future<void> setGeofenceAlerts(bool value) async {
    await prefs.setBool(keyGeofenceAlerts, value);
    AppLogger.info('🚧 Geofence alerts: ${value ? "ON" : "OFF"}');
  }

  bool get notificationSound => 
      prefs.getBool(keyNotificationSound) ?? defaultNotificationSound;
  
  Future<void> setNotificationSound(bool value) async {
    await prefs.setBool(keyNotificationSound, value);
    AppLogger.info('🔊 Notification sound: ${value ? "ON" : "OFF"}');
  }

  bool get notificationVibration => 
      prefs.getBool(keyNotificationVibration) ?? defaultNotificationVibration;
  
  Future<void> setNotificationVibration(bool value) async {
    await prefs.setBool(keyNotificationVibration, value);
    AppLogger.info('📳 Notification vibration: ${value ? "ON" : "OFF"}');
  }

  // ========== APPEARANCE ==========

  bool get darkMode => 
      prefs.getBool(keyDarkMode) ?? defaultDarkMode;
  
  Future<void> setDarkMode(bool value) async {
    await prefs.setBool(keyDarkMode, value);
    AppLogger.info('🌙 Dark mode: ${value ? "ON" : "OFF"}');
  }

  String get language => 
      prefs.getString(keyLanguage) ?? defaultLanguage;
  
  Future<void> setLanguage(String value) async {
    await prefs.setString(keyLanguage, value);
    AppLogger.info('🌐 Language: $value');
  }

  // ========== MAP SETTINGS ==========

  String get mapType => 
      prefs.getString(keyMapType) ?? defaultMapType;
  
  Future<void> setMapType(String value) async {
    await prefs.setString(keyMapType, value);
    AppLogger.info('🗺️ Map type: $value');
  }

  int get proximityRadius => 
      prefs.getInt(keyProximityRadius) ?? defaultProximityRadius;
  
  Future<void> setProximityRadius(int value) async {
    await prefs.setInt(keyProximityRadius, value);
    AppLogger.info('📏 Proximity radius: ${value}km');
  }

  bool get showResolvedAlerts => 
      prefs.getBool(keyShowResolvedAlerts) ?? defaultShowResolvedAlerts;
  
  Future<void> setShowResolvedAlerts(bool value) async {
    await prefs.setBool(keyShowResolvedAlerts, value);
    AppLogger.info('✅ Show resolved alerts: ${value ? "ON" : "OFF"}');
  }

  // ========== ADVANCED ==========

  bool get offlineMode => 
      prefs.getBool(keyOfflineMode) ?? defaultOfflineMode;
  
  Future<void> setOfflineMode(bool value) async {
    await prefs.setBool(keyOfflineMode, value);
    AppLogger.info('📴 Offline mode: ${value ? "ON" : "OFF"}');
  }

  // ========== THREAD-SAFE GENERIC METHODS ==========

  /// Thread-safe generic getter for any type
  Future<T?> getValue<T>(String key) async {
    final prefs = await safePrefs;
    switch (T) {
      case bool:
        return prefs.getBool(key) as T?;
      case int:
        return prefs.getInt(key) as T?;
      case double:
        return prefs.getDouble(key) as T?;
      case String:
        return prefs.getString(key) as T?;
      case const (List<String>):
        return prefs.getStringList(key) as T?;
      default:
        throw ArgumentError('Unsupported type: $T');
    }
  }

  /// Thread-safe generic setter for any type
  Future<bool> setValue<T>(String key, T value) async {
    final prefs = await safePrefs;
    switch (T) {
      case bool:
        return await prefs.setBool(key, value as bool);
      case int:
        return await prefs.setInt(key, value as int);
      case double:
        return await prefs.setDouble(key, value as double);
      case String:
        return await prefs.setString(key, value as String);
      case const (List<String>):
        return await prefs.setStringList(key, value as List<String>);
      default:
        throw ArgumentError('Unsupported type: $T');
    }
  }

  /// Thread-safe generic getter with default value
  Future<T> getValueWithDefault<T>(String key, T defaultValue) async {
    final value = await getValue<T>(key);
    return value ?? defaultValue;
  }

  /// Thread-safe boolean getter
  Future<bool> getBoolSafe(String key, {bool defaultValue = false}) async {
    return await getValueWithDefault<bool>(key, defaultValue);
  }

  /// Thread-safe integer getter
  Future<int> getIntSafe(String key, {int defaultValue = 0}) async {
    return await getValueWithDefault<int>(key, defaultValue);
  }

  /// Thread-safe string getter
  Future<String> getStringSafe(String key, {String defaultValue = ''}) async {
    return await getValueWithDefault<String>(key, defaultValue);
  }

  /// Thread-safe boolean setter
  Future<void> setBoolSafe(String key, bool value) async {
    await setValue<bool>(key, value);
    AppLogger.info('⚙️ Setting updated: $key = $value');
  }

  /// Thread-safe integer setter
  Future<void> setIntSafe(String key, int value) async {
    await setValue<int>(key, value);
    AppLogger.info('⚙️ Setting updated: $key = $value');
  }

  /// Thread-safe string setter
  Future<void> setStringSafe(String key, String value) async {
    await setValue<String>(key, value);
    AppLogger.info('⚙️ Setting updated: $key = $value');
  }

  // ========== UTILITY METHODS ==========

  /// Reset all settings to defaults (thread-safe)
  Future<void> resetToDefaults() async {
    final prefsInstance = await safePrefs;
    await prefsInstance.clear();
    AppLogger.warning('🔄 All settings reset to defaults');
  }

  /// Get all settings as a map (thread-safe for debugging)
  Future<Map<String, dynamic>> getAllSettings() async {
    final prefsInstance = await safePrefs;
    return {
      'location_tracking': prefsInstance.getBool(keyLocationTracking) ?? defaultLocationTracking,
      'push_notifications': prefsInstance.getBool(keyPushNotifications) ?? defaultPushNotifications,
      'sos_alerts': prefsInstance.getBool(keySosAlerts) ?? defaultSosAlerts,
      'safety_alerts': prefsInstance.getBool(keySafetyAlerts) ?? defaultSafetyAlerts,
      'proximity_alerts': prefsInstance.getBool(keyProximityAlerts) ?? defaultProximityAlerts,
      'geofence_alerts': prefsInstance.getBool(keyGeofenceAlerts) ?? defaultGeofenceAlerts,
      'battery_optimization': prefsInstance.getBool(keyBatteryOptimization) ?? defaultBatteryOptimization,
      'update_interval': prefsInstance.getString(keyUpdateInterval) ?? defaultUpdateInterval,
      'notification_sound': prefsInstance.getBool(keyNotificationSound) ?? defaultNotificationSound,
      'notification_vibration': prefsInstance.getBool(keyNotificationVibration) ?? defaultNotificationVibration,
      'auto_start_tracking': prefsInstance.getBool(keyAutoStartTracking) ?? defaultAutoStartTracking,
      'dark_mode': prefsInstance.getBool(keyDarkMode) ?? defaultDarkMode,
      'language': prefsInstance.getString(keyLanguage) ?? 'en',
      'map_type': prefsInstance.getString(keyMapType) ?? 'OpenStreetMap',
      'proximity_radius': prefsInstance.getInt(keyProximityRadius) ?? 100,
      'show_resolved_alerts': prefsInstance.getBool(keyShowResolvedAlerts) ?? false,
      'offline_mode': prefsInstance.getBool(keyOfflineMode) ?? false,
    };
  }

  /// Export settings as JSON string (thread-safe)
  Future<String> exportSettings() async {
    final settings = await getAllSettings();
    return settings.toString();
  }

  /// Print all settings (thread-safe debug)
  Future<void> printAllSettings() async {
    AppLogger.info('📋 Current Settings:');
    final settings = await getAllSettings();
    settings.forEach((key, value) {
      AppLogger.info('  $key: $value');
    });
  }

  // ========== LEGACY METHODS (DEPRECATED) ==========
  // These methods are deprecated in favor of thread-safe versions above.
  // They use the synchronous 'prefs' getter which can cause race conditions.

  /// Generic get boolean with default value
  /// @deprecated Use getBoolSafe instead for thread safety
  @Deprecated('Use getBoolSafe for thread safety')
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    return prefs.getBool(key) ?? defaultValue;
  }

  /// Generic set boolean
  /// @deprecated Use setBoolSafe instead for thread safety
  @Deprecated('Use setBoolSafe for thread safety')
  Future<void> setBool(String key, bool value) async {
    await prefs.setBool(key, value);
  }

  /// Generic get integer with default value
  /// @deprecated Use getIntSafe instead for thread safety
  @Deprecated('Use getIntSafe for thread safety')
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    return prefs.getInt(key) ?? defaultValue;
  }

  /// Generic set integer
  /// @deprecated Use setIntSafe instead for thread safety
  @Deprecated('Use setIntSafe for thread safety')  
  Future<void> setInt(String key, int value) async {
    await prefs.setInt(key, value);
  }

  /// Generic get string with default value
  /// @deprecated Use getStringSafe instead for thread safety
  @Deprecated('Use getStringSafe for thread safety')
  Future<String> getString(String key, {String defaultValue = ''}) async {
    return prefs.getString(key) ?? defaultValue;
  }

  /// Generic set string
  /// @deprecated Use setStringSafe instead for thread safety
  @Deprecated('Use setStringSafe for thread safety')
  Future<void> setString(String key, String value) async {
    await prefs.setString(key, value);
  }
}
