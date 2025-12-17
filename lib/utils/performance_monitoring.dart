import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../utils/logger.dart';

/// Comprehensive performance monitoring and analytics system
/// Features: Real-time metrics, crash reporting, analytics tracking,
/// performance diagnostics, and optimization recommendations

/// Performance metric types
enum MetricType {
  appLaunch,
  apiResponse,
  databaseQuery,
  cacheHit,
  locationUpdate,
  uiRender,
  memoryUsage,
  batteryDrain,
  networkLatency,
  errorOccurrence,
}

/// Performance severity levels
enum PerformanceSeverity {
  excellent,
  good,
  acceptable,
  poor,
  critical,
}

/// Performance metric data structure
class PerformanceMetric {
  final String id;
  final MetricType type;
  final double value;
  final String unit;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;
  final String? category;
  final PerformanceSeverity severity;
  
  PerformanceMetric({
    required this.id,
    required this.type,
    required this.value,
    required this.unit,
    this.metadata = const {},
    this.category,
    required this.severity,
  }) : timestamp = DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString(),
    'value': value,
    'unit': unit,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
    'category': category,
    'severity': severity.toString(),
  };
  
  factory PerformanceMetric.fromJson(Map<String, dynamic> json) {
    return PerformanceMetric(
      id: json['id'],
      type: MetricType.values.firstWhere((e) => e.toString() == json['type']),
      value: json['value'].toDouble(),
      unit: json['unit'],
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
      category: json['category'],
      severity: PerformanceSeverity.values.firstWhere((e) => e.toString() == json['severity']),
    );
  }
}

/// Crash report data structure
class CrashReport {
  final String id;
  final String error;
  final String? stackTrace;
  final DateTime timestamp;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> appInfo;
  final Map<String, dynamic> userActions;
  final String severity;
  
  CrashReport({
    required this.id,
    required this.error,
    this.stackTrace,
    required this.deviceInfo,
    required this.appInfo,
    required this.userActions,
    required this.severity,
  }) : timestamp = DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'error': error,
    'stackTrace': stackTrace,
    'timestamp': timestamp.toIso8601String(),
    'deviceInfo': deviceInfo,
    'appInfo': appInfo,
    'userActions': userActions,
    'severity': severity,
  };
}

/// Analytics event data structure
class AnalyticsEvent {
  final String name;
  final String category;
  final Map<String, dynamic> parameters;
  final DateTime timestamp;
  final String? userId;
  final String? sessionId;
  
  AnalyticsEvent({
    required this.name,
    required this.category,
    this.parameters = const {},
    this.userId,
    this.sessionId,
  }) : timestamp = DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'parameters': parameters,
    'timestamp': timestamp.toIso8601String(),
    'userId': userId,
    'sessionId': sessionId,
  };
}

/// Comprehensive performance monitoring manager
class PerformanceMonitor {
  static PerformanceMonitor? _instance;
  static PerformanceMonitor get instance => 
      _instance ??= PerformanceMonitor._internal();
  PerformanceMonitor._internal();

  final Queue<PerformanceMetric> _metrics = Queue<PerformanceMetric>();
  final Queue<CrashReport> _crashReports = Queue<CrashReport>();
  final Map<MetricType, List<double>> _metricHistory = {};
  final Map<String, DateTime> _operationStartTimes = {};
  
  // Configuration
  static const int _maxMetrics = 1000;
  static const int _maxCrashReports = 50;
  static const Duration _reportingInterval = Duration(minutes: 5);
  
  Timer? _reportingTimer;
  bool _isInitialized = false;
  
  /// Initialize performance monitoring
  Future<void> initialize() async {
    try {
      if (_isInitialized) return;
      
      // Initialize metric history
      for (final type in MetricType.values) {
        _metricHistory[type] = <double>[];
      }
      
      // Start periodic reporting
      _startPeriodicReporting();
      
      // Set up Flutter error handling
      FlutterError.onError = (FlutterErrorDetails details) {
        _recordCrash(
          error: details.exception.toString(),
          stackTrace: details.stack.toString(),
          severity: 'high',
        );
      };
      
      // Set up platform error handling
      PlatformDispatcher.instance.onError = (error, stack) {
        _recordCrash(
          error: error.toString(),
          stackTrace: stack.toString(),
          severity: 'critical',
        );
        return true;
      };
      
      _isInitialized = true;
      AppLogger.info('Performance monitoring initialized');
      
      // Record initialization metric
      recordMetric(PerformanceMetric(
        id: _generateId(),
        type: MetricType.appLaunch,
        value: DateTime.now().millisecondsSinceEpoch.toDouble(),
        unit: 'ms',
        severity: PerformanceSeverity.good,
        category: 'initialization',
      ));
    } catch (e) {
      AppLogger.error('Performance monitoring initialization failed: $e');
    }
  }
  
  void _startPeriodicReporting() {
    _reportingTimer = Timer.periodic(_reportingInterval, (timer) {
      _generatePerformanceReport();
      _cleanupOldData();
    });
  }
  
  /// Record a performance metric
  void recordMetric(PerformanceMetric metric) {
    _metrics.add(metric);
    
    // Update history
    _metricHistory[metric.type]?.add(metric.value);
    if (_metricHistory[metric.type]!.length > 100) {
      _metricHistory[metric.type]!.removeAt(0);
    }
    
    // Cleanup old metrics
    if (_metrics.length > _maxMetrics) {
      _metrics.removeFirst();
    }
    
    // Log performance issues
    if (metric.severity == PerformanceSeverity.poor || 
        metric.severity == PerformanceSeverity.critical) {
      AppLogger.warning('Performance issue: ${metric.type} - ${metric.value}${metric.unit}');
    }
  }
  
  /// Start tracking an operation
  void startOperation(String operationId) {
    _operationStartTimes[operationId] = DateTime.now();
  }
  
  /// End tracking an operation and record metric
  void endOperation(String operationId, MetricType type, {
    String? category,
    Map<String, dynamic>? metadata,
  }) {
    final startTime = _operationStartTimes.remove(operationId);
    if (startTime == null) return;
    
    final duration = DateTime.now().difference(startTime).inMilliseconds.toDouble();
    final severity = _calculateSeverity(type, duration);
    
    recordMetric(PerformanceMetric(
      id: _generateId(),
      type: type,
      value: duration,
      unit: 'ms',
      severity: severity,
      category: category,
      metadata: metadata ?? {},
    ));
  }
  
  PerformanceSeverity _calculateSeverity(MetricType type, double value) {
    // Define performance thresholds for different metric types
    final thresholds = {
      MetricType.apiResponse: [100, 300, 1000, 3000], // ms
      MetricType.databaseQuery: [10, 50, 200, 500], // ms
      MetricType.uiRender: [16, 33, 100, 300], // ms (60fps = 16ms)
      MetricType.locationUpdate: [1000, 3000, 10000, 30000], // ms
      MetricType.appLaunch: [1000, 2000, 5000, 10000], // ms
    };
    
    final typeThresholds = thresholds[type] ?? [100, 500, 2000, 5000];
    
    if (value <= typeThresholds[0]) return PerformanceSeverity.excellent;
    if (value <= typeThresholds[1]) return PerformanceSeverity.good;
    if (value <= typeThresholds[2]) return PerformanceSeverity.acceptable;
    if (value <= typeThresholds[3]) return PerformanceSeverity.poor;
    return PerformanceSeverity.critical;
  }
  
  /// Record a crash
  void _recordCrash({
    required String error,
    String? stackTrace,
    required String severity,
  }) async {
    try {
      final deviceInfo = await _getDeviceInfo();
      final appInfo = await _getAppInfo();
      
      final crashReport = CrashReport(
        id: _generateId(),
        error: error,
        stackTrace: stackTrace,
        deviceInfo: deviceInfo,
        appInfo: appInfo,
        userActions: _getRecentUserActions(),
        severity: severity,
      );
      
      _crashReports.add(crashReport);
      
      // Cleanup old crash reports
      if (_crashReports.length > _maxCrashReports) {
        _crashReports.removeFirst();
      }
      
      AppLogger.error('Crash recorded: $error');
      
      // Could send crash report to external service here
      await _saveCrashReport(crashReport);
    } catch (e) {
      AppLogger.error('Failed to record crash: $e');
    }
  }
  
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return {
          'platform': 'Android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'brand': androidInfo.brand,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'platform': 'iOS',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
        };
      }
    } catch (e) {
      AppLogger.warning('Failed to get device info: $e');
    }
    
    return {'platform': 'Unknown'};
  }
  
  Future<Map<String, dynamic>> _getAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return {
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'version': packageInfo.version,
        'buildNumber': packageInfo.buildNumber,
      };
    } catch (e) {
      AppLogger.warning('Failed to get app info: $e');
      return {};
    }
  }
  
  Map<String, dynamic> _getRecentUserActions() {
    // Implement user action tracking if needed
    return {
      'last_screen': 'unknown',
      'session_duration': DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  Future<void> _saveCrashReport(CrashReport report) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final reports = prefs.getStringList('crash_reports') ?? [];
      reports.add(jsonEncode(report.toJson()));
      
      // Keep only recent reports
      if (reports.length > _maxCrashReports) {
        reports.removeRange(0, reports.length - _maxCrashReports);
      }
      
      await prefs.setStringList('crash_reports', reports);
    } catch (e) {
      AppLogger.error('Failed to save crash report: $e');
    }
  }
  
  void _generatePerformanceReport() {
    try {
      final report = _createPerformanceReport();
      AppLogger.info('Performance report: ${jsonEncode(report)}');
      
      // Could send report to analytics service here
      _sendPerformanceData(report);
    } catch (e) {
      AppLogger.error('Failed to generate performance report: $e');
    }
  }
  
  Map<String, dynamic> _createPerformanceReport() {
    final recentMetrics = _metrics.where((m) =>
        DateTime.now().difference(m.timestamp) < _reportingInterval
    ).toList();
    
    final metricsByType = <String, List<double>>{};
    for (final metric in recentMetrics) {
      final typeName = metric.type.toString();
      metricsByType[typeName] ??= [];
      metricsByType[typeName]!.add(metric.value);
    }
    
    final aggregated = <String, Map<String, double>>{};
    for (final entry in metricsByType.entries) {
      final values = entry.value;
      if (values.isNotEmpty) {
        values.sort();
        aggregated[entry.key] = {
          'count': values.length.toDouble(),
          'min': values.first,
          'max': values.last,
          'avg': values.reduce((a, b) => a + b) / values.length,
          'p50': values[values.length ~/ 2],
          'p95': values[(values.length * 0.95).floor()],
          'p99': values[(values.length * 0.99).floor()],
        };
      }
    }
    
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'metrics': aggregated,
      'crash_count': _crashReports.length,
      'total_metrics': _metrics.length,
    };
  }
  
  Future<void> _sendPerformanceData(Map<String, dynamic> data) async {
    // Implement sending to analytics service
    AppLogger.debug('Performance data ready for transmission: ${data.length} bytes');
  }
  
  void _cleanupOldData() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    
    // Cleanup old metrics
    _metrics.removeWhere((metric) => metric.timestamp.isBefore(cutoff));
    
    // Cleanup old crash reports
    _crashReports.removeWhere((report) => report.timestamp.isBefore(cutoff));
  }
  
  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};
    
    for (final entry in _metricHistory.entries) {
      final values = entry.value;
      if (values.isNotEmpty) {
        final sorted = List<double>.from(values)..sort();
        stats[entry.key.toString()] = {
          'count': values.length,
          'avg': values.reduce((a, b) => a + b) / values.length,
          'min': sorted.first,
          'max': sorted.last,
          'p95': sorted[(sorted.length * 0.95).floor()],
        };
      }
    }
    
    return {
      'metrics': stats,
      'crashes': _crashReports.length,
      'uptime': DateTime.now().millisecondsSinceEpoch,
    };
  }
  
  /// Get recent crash reports
  List<CrashReport> getCrashReports() {
    return List.from(_crashReports);
  }
  
  /// Get optimization recommendations
  List<String> getOptimizationRecommendations() {
    final recommendations = <String>[];
    
    // Analyze performance data and provide recommendations
    for (final entry in _metricHistory.entries) {
      final values = entry.value;
      if (values.isNotEmpty) {
        final avg = values.reduce((a, b) => a + b) / values.length;
        final severity = _calculateSeverity(entry.key, avg);
        
        if (severity == PerformanceSeverity.poor || 
            severity == PerformanceSeverity.critical) {
          recommendations.add(_getRecommendation(entry.key, avg));
        }
      }
    }
    
    if (_crashReports.length > 5) {
      recommendations.add('High crash rate detected. Review error handling and stability.');
    }
    
    return recommendations;
  }
  
  String _getRecommendation(MetricType type, double avgValue) {
    switch (type) {
      case MetricType.apiResponse:
        return 'API responses are slow (${avgValue.toInt()}ms). Consider caching, request optimization, or CDN.';
      case MetricType.databaseQuery:
        return 'Database queries are slow (${avgValue.toInt()}ms). Consider indexing or query optimization.';
      case MetricType.uiRender:
        return 'UI rendering is slow (${avgValue.toInt()}ms). Consider reducing widget complexity or using builders.';
      case MetricType.locationUpdate:
        return 'Location updates are slow (${avgValue.toInt()}ms). Consider adjusting update intervals.';
      case MetricType.appLaunch:
        return 'App launch is slow (${avgValue.toInt()}ms). Consider reducing initialization work.';
      default:
        return 'Performance issue detected in ${type.toString()}.';
    }
  }
  
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_metrics.length}';
  }
  
  void dispose() {
    _reportingTimer?.cancel();
    _generatePerformanceReport(); // Final report
  }
}

/// Analytics tracking manager
class AnalyticsManager {
  static AnalyticsManager? _instance;
  static AnalyticsManager get instance => 
      _instance ??= AnalyticsManager._internal();
  AnalyticsManager._internal();

  final Queue<AnalyticsEvent> _events = Queue<AnalyticsEvent>();
  String? _sessionId;
  String? _userId;
  Timer? _flushTimer;
  
  static const int _maxEvents = 500;
  static const Duration _flushInterval = Duration(minutes: 2);
  
  /// Initialize analytics
  void initialize({String? userId}) async {
    _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
    _userId = userId;
    
    _startPeriodicFlush();
    AppLogger.info('Analytics initialized (session: $_sessionId)');
    
    // Track app start
    trackEvent('app_start', 'lifecycle', {
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  void _startPeriodicFlush() {
    _flushTimer = Timer.periodic(_flushInterval, (timer) {
      _flushEvents();
    });
  }
  
  /// Track an analytics event
  void trackEvent(String name, String category, [Map<String, dynamic>? parameters]) {
    final event = AnalyticsEvent(
      name: name,
      category: category,
      parameters: parameters ?? {},
      userId: _userId,
      sessionId: _sessionId,
    );
    
    _events.add(event);
    
    // Cleanup old events
    if (_events.length > _maxEvents) {
      _events.removeFirst();
    }
    
    AppLogger.debug('Analytics event: $name ($category)');
  }
  
  /// Track screen view
  void trackScreenView(String screenName) {
    trackEvent('screen_view', 'navigation', {
      'screen_name': screenName,
    });
  }
  
  /// Track user action
  void trackUserAction(String action, {Map<String, dynamic>? properties}) {
    trackEvent(action, 'user_action', properties);
  }
  
  /// Track error occurrence
  void trackError(String error, {String? category}) {
    trackEvent('error_occurred', category ?? 'error', {
      'error_message': error,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  void _flushEvents() {
    if (_events.isEmpty) return;
    
    try {
      final eventsToSend = List<AnalyticsEvent>.from(_events);
      _events.clear();
      
      // Send events to analytics service
      _sendAnalyticsData(eventsToSend);
      
      AppLogger.debug('Flushed ${eventsToSend.length} analytics events');
    } catch (e) {
      AppLogger.error('Failed to flush analytics events: $e');
    }
  }
  
  Future<void> _sendAnalyticsData(List<AnalyticsEvent> events) async {
    // Implement sending to analytics service
    final data = events.map((e) => e.toJson()).toList();
    AppLogger.debug('Analytics data ready: ${data.length} events');
  }
  
  /// Get analytics summary
  Map<String, dynamic> getAnalyticsSummary() {
    final eventsByCategory = <String, int>{};
    final eventsByName = <String, int>{};
    
    for (final event in _events) {
      eventsByCategory[event.category] = (eventsByCategory[event.category] ?? 0) + 1;
      eventsByName[event.name] = (eventsByName[event.name] ?? 0) + 1;
    }
    
    return {
      'session_id': _sessionId,
      'user_id': _userId,
      'total_events': _events.length,
      'events_by_category': eventsByCategory,
      'events_by_name': eventsByName,
    };
  }
  
  void dispose() {
    _flushTimer?.cancel();
    _flushEvents(); // Final flush
  }
}