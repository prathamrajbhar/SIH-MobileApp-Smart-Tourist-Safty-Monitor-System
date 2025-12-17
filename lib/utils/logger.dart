import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized logging utility for the SafeHorizon Tourist App
/// Provides structured, configurable logging with clear categorization
class AppLogger {
  static bool get _isDebugMode => dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
  static bool get _isProductionMode => kReleaseMode;
  
  // Log levels
  static const String _info = 'INFO';
  static const String _warning = 'WARN';
  static const String _error = 'ERROR';
  static const String _debug = 'DEBUG';
  static const String _api = 'API';
  static const String _location = 'LOCATION';
  static const String _auth = 'AUTH';
  static const String _emergency = 'EMERGENCY';
  static const String _service = 'SERVICE';

  /// Log information messages
  static void info(String message, {String? category}) {
    _log(_info, message, category: category);
  }

  /// Log warning messages
  static void warning(String message, {String? category}) {
    _log(_warning, message, category: category);
  }

  /// Log error messages with optional error object
  static void error(String message, {Object? error, String? category}) {
    final errorMessage = error != null ? '$message: $error' : message;
    _log(_error, errorMessage, category: category);
  }

  /// Log debug messages (only in debug mode)
  static void debug(String message, {String? category}) {
    if (_isDebugMode && !_isProductionMode) {
      _log(_debug, message, category: category);
    }
  }

  /// Log API-related messages
  static void api(String message, {bool isError = false}) {
    _log(isError ? _error : _info, message, category: _api);
  }

  /// Log location-related messages
  static void location(String message, {bool isError = false}) {
    _log(isError ? _error : _info, message, category: _location);
  }

  /// Log authentication-related messages
  static void auth(String message, {bool isError = false}) {
    _log(isError ? _error : _info, message, category: _auth);
  }

  /// Log emergency-related messages (always shown in production)
  static void emergency(String message, {bool isError = false}) {
    _log(isError ? _error : _warning, message, category: _emergency, forceLog: true);
  }

  /// Log service-related messages
  static void service(String message, {bool isError = false}) {
    _log(isError ? _error : _info, message, category: _service);
  }

  /// Internal logging method
  static void _log(String level, String message, {String? category, bool forceLog = false}) {
    // Force log emergency messages and errors always
    final shouldForceLog = forceLog || level == _error || level == _warning;
    
    // In production, only log errors, warnings, and emergency messages
    if (_isProductionMode && !shouldForceLog) return;
    
    // In debug mode, respect DEBUG_MODE setting unless it's a force log
    if (!_isProductionMode && !_isDebugMode && !shouldForceLog) return;

    final timestamp = DateTime.now().toIso8601String().substring(11, 23); // HH:mm:ss.mmm
    final categoryPrefix = category != null ? '[$category] ' : '';
    final formattedMessage = '[$timestamp] [$level] $categoryPrefix$message';
    
    // Use regular print to ensure visibility in terminal output
    print(formattedMessage);
  }

  /// Log API request details
  static void apiRequest(String method, String endpoint, {Map<String, dynamic>? data}) {
    if (_isDebugMode) {
      final dataStr = data != null ? ' | Data: ${data.toString()}' : '';
      api('$method $endpoint$dataStr');
    }
  }

  /// Log API response details
  static void apiResponse(String endpoint, int statusCode, {String? message}) {
    final status = statusCode >= 200 && statusCode < 300 ? 'SUCCESS' : 'FAILED';
    final msg = message != null ? ' | $message' : '';
    api('$endpoint | $status ($statusCode)$msg', isError: statusCode >= 400);
  }

  /// Log location updates
  static void locationUpdate(double lat, double lon, {double? accuracy}) {
    if (_isDebugMode) {
      final accuracyStr = accuracy != null ? ' ±${accuracy.toStringAsFixed(1)}m' : '';
      location('Position updated: ${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}$accuracyStr');
    }
  }

  /// Log authentication events
  static void authEvent(String event, {bool success = true, String? details}) {
    final status = success ? 'SUCCESS' : 'FAILED';
    final detailsStr = details != null ? ' | $details' : '';
    auth('$event | $status$detailsStr', isError: !success);
  }

  /// Log service lifecycle events
  static void serviceEvent(String serviceName, String event, {String? details}) {
    final detailsStr = details != null ? ' | $details' : '';
    service('$serviceName | $event$detailsStr');
  }

  /// Log user actions for analytics (only in debug mode)
  static void userAction(String action, {Map<String, dynamic>? context}) {
    if (_isDebugMode) {
      final contextStr = context != null ? ' | Context: ${context.toString()}' : '';
      info('USER_ACTION: $action$contextStr', category: 'USER');
    }
  }

  /// Log performance metrics (only in debug mode)
  static void performance(String operation, Duration duration, {String? details}) {
    if (_isDebugMode) {
      final detailsStr = details != null ? ' | $details' : '';
      info('PERF: $operation took ${duration.inMilliseconds}ms$detailsStr', category: 'PERF');
    }
  }

  /// Clear console (for testing purposes in debug mode)
  static void clearConsole() {
    if (_isDebugMode && !_isProductionMode) {
      debugPrint('\x1B[2J\x1B[0;0H'); // ANSI escape codes to clear console
    }
  }
}
