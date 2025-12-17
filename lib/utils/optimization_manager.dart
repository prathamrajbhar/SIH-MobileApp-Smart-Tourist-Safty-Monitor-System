import 'dart:async';
import 'package:flutter/foundation.dart';

import '../utils/logger.dart';
import '../utils/caching_and_offline.dart';
import '../utils/security_framework.dart';
import '../utils/performance_monitoring.dart' as perf;

/// Comprehensive optimization system integration
/// This file coordinates all optimization frameworks for maximum robustness
/// 
/// Features integrated:
/// - Circuit breakers and retry mechanisms
/// - Intelligent caching and offline support
/// - Advanced security with encryption
/// - Performance monitoring and analytics
/// - Error handling and resilience
/// - Optimized state management

class OptimizationManager {
  static OptimizationManager? _instance;
  static OptimizationManager get instance => 
      _instance ??= OptimizationManager._internal();
  OptimizationManager._internal();

  bool _isInitialized = false;
  final List<String> _initializationLog = [];
  
  /// Initialize all optimization systems
  Future<void> initializeAll() async {
    if (_isInitialized) {
      AppLogger.info('Optimization systems already initialized');
      return;
    }
    
    AppLogger.info('🚀 Starting comprehensive optimization initialization...');
    final startTime = DateTime.now();
    
    try {
      // 1. Initialize core logging and error handling
      await _initializeErrorHandling();
      
      // 2. Initialize security framework first (foundational)
      await _initializeSecurity();
      
      // 3. Initialize caching and offline support
      await _initializeCaching();
      
      // 4. Initialize performance monitoring
      await _initializePerformanceMonitoring();
      
      _isInitialized = true;
      
      final duration = DateTime.now().difference(startTime);
      AppLogger.info('✅ All optimization systems initialized successfully in ${duration.inMilliseconds}ms');
      
      // Log initialization summary
      _logInitializationSummary();
      
      // Start monitoring optimizations
      _startOptimizationMonitoring();
      
    } catch (e, stackTrace) {
      AppLogger.error('❌ Optimization initialization failed: $e');
      AppLogger.error('Stack trace: $stackTrace');
      
      // Attempt graceful degradation
      await _handleInitializationFailure(e);
      rethrow;
    }
  }
  
  Future<void> _initializeErrorHandling() async {
    try {
      // Initialize global error handling
      FlutterError.onError = (FlutterErrorDetails details) {
        AppLogger.error('Flutter Error: ${details.exception}');
        
        // Record error metric
        perf.PerformanceMonitor.instance.recordMetric(perf.PerformanceMetric(
          id: 'error_${DateTime.now().millisecondsSinceEpoch}',
          type: perf.MetricType.errorOccurrence,
          value: 1,
          unit: 'count',
          severity: perf.PerformanceSeverity.critical,
          metadata: {'error_type': 'flutter_error'},
        ));
      };
      
      _initializationLog.add('✅ Error handling framework initialized');
      AppLogger.info('Error handling framework initialized');
    } catch (e) {
      _initializationLog.add('❌ Error handling initialization failed: $e');
      rethrow;
    }
  }
  
  Future<void> _initializeSecurity() async {
    try {
      // Initialize encryption service
      await AdvancedEncryptionService.instance.initialize();
      
      // Initialize secure storage
      await SecureStorageManager.instance.initialize();
      
      // Initialize security monitoring
      SecurityMonitor.instance.initialize();
      
      _initializationLog.add('✅ Security framework initialized');
      AppLogger.info('Security framework initialized with encryption and monitoring');
    } catch (e) {
      _initializationLog.add('❌ Security initialization failed: $e');
      rethrow;
    }
  }
  
  Future<void> _initializeCaching() async {
    try {
      // Initialize cache manager
      await OptimizedCacheManager.instance.initialize();
      
      // Initialize offline sync manager
      await OfflineSyncManager.instance.initialize();
      
      _initializationLog.add('✅ Caching and offline support initialized');
      AppLogger.info('Multi-layer caching and offline sync initialized');
    } catch (e) {
      _initializationLog.add('❌ Caching initialization failed: $e');
      rethrow;
    }
  }
  
  Future<void> _initializePerformanceMonitoring() async {
    try {
      // Initialize performance monitoring
      await perf.PerformanceMonitor.instance.initialize();
      
      // Initialize analytics
      perf.AnalyticsManager.instance.initialize();
      
      _initializationLog.add('✅ Performance monitoring and analytics initialized');
      AppLogger.info('Performance monitoring and analytics tracking enabled');
    } catch (e) {
      _initializationLog.add('❌ Performance monitoring initialization failed: $e');
      rethrow;
    }
  }
  
  void _logInitializationSummary() {
    AppLogger.info('📊 Optimization Initialization Summary:');
    for (final log in _initializationLog) {
      AppLogger.info('  $log');
    }
    
    AppLogger.info('');
    AppLogger.info('🔧 Active Optimization Features:');
    AppLogger.info('  • Circuit breakers and retry mechanisms');
    AppLogger.info('  • Multi-layer caching (memory + disk)');
    AppLogger.info('  • Offline queue and sync management');
    AppLogger.info('  • Advanced encryption and secure storage');
    AppLogger.info('  • Real-time performance monitoring');
    AppLogger.info('  • Comprehensive error handling');
    AppLogger.info('  • Analytics and crash reporting');
    AppLogger.info('  • Optimized state management');
    AppLogger.info('');
  }
  
  void _startOptimizationMonitoring() {
    // Start monitoring optimization effectiveness
    Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkOptimizationHealth();
    });
  }
  
  void _checkOptimizationHealth() {
    try {
      // Get performance stats
      final perfStats = perf.PerformanceMonitor.instance.getPerformanceStats();
      
      // Get cache stats
      final cacheStats = OptimizedCacheManager.instance.getStats();
      
      // Get security stats
      final securityStats = SecurityMonitor.instance.getSecurityStats();
      
      // Log optimization effectiveness
      final hitRate = cacheStats['hitRate'] ?? 0.0;
      final crashCount = perfStats['crashes'] ?? 0;
      final securityEvents = securityStats['recent_events'] ?? 0;
      
      AppLogger.info('🔍 Optimization Health Check:');
      AppLogger.info('  Cache Hit Rate: ${(hitRate * 100).toStringAsFixed(1)}%');
      AppLogger.info('  Recent Crashes: $crashCount');
      AppLogger.info('  Security Events: $securityEvents');
      
      // Record health metrics
      perf.PerformanceMonitor.instance.recordMetric(perf.PerformanceMetric(
        id: 'health_check_${DateTime.now().millisecondsSinceEpoch}',
        type: perf.MetricType.memoryUsage,
        value: hitRate,
        unit: 'ratio',
        severity: hitRate > 0.8 ? perf.PerformanceSeverity.excellent : 
                 hitRate > 0.6 ? perf.PerformanceSeverity.good : perf.PerformanceSeverity.acceptable,
        category: 'optimization_health',
      ));
      
      // Get optimization recommendations
      final recommendations = perf.PerformanceMonitor.instance.getOptimizationRecommendations();
      if (recommendations.isNotEmpty) {
        AppLogger.info('💡 Optimization Recommendations:');
        for (final rec in recommendations) {
          AppLogger.info('  • $rec');
        }
      }
      
    } catch (e) {
      AppLogger.warning('Optimization health check failed: $e');
    }
  }
  
  Future<void> _handleInitializationFailure(dynamic error) async {
    AppLogger.error('Attempting graceful degradation due to initialization failure');
    
    try {
      // At minimum, ensure basic logging works
      AppLogger.warning('Running in degraded mode - some optimizations may not be available');
      
      // Track the initialization failure
      perf.AnalyticsManager.instance.trackError(
        'Optimization initialization failed: $error',
        category: 'initialization',
      );
      
    } catch (e) {
      // If even graceful degradation fails, log to console
      if (kDebugMode) {
        print('Critical failure: Unable to initialize optimization systems: $e');
      }
    }
  }
  
  /// Get comprehensive system status
  Map<String, dynamic> getSystemStatus() {
    if (!_isInitialized) {
      return {'status': 'not_initialized'};
    }
    
    try {
      return {
        'status': 'initialized',
        'initialization_steps': _initializationLog.length,
        'performance': perf.PerformanceMonitor.instance.getPerformanceStats(),
        'cache': OptimizedCacheManager.instance.getStats(),
        'security': SecurityMonitor.instance.getSecurityStats(),
        'offline_queue': OfflineSyncManager.instance.queueSize,
        'is_online': OfflineSyncManager.instance.isOnline,
        'recommendations': perf.PerformanceMonitor.instance.getOptimizationRecommendations(),
      };
    } catch (e) {
      AppLogger.error('Failed to get system status: $e');
      return {'status': 'error', 'error': e.toString()};
    }
  }
  
  /// Force system optimization check
  Future<void> forceOptimizationCheck() async {
    try {
      AppLogger.info('🔄 Running forced optimization check...');
      
      // Force cache cleanup
      OptimizedCacheManager.instance.dispose();
      await OptimizedCacheManager.instance.initialize();
      
      // Force sync if online
      if (OfflineSyncManager.instance.isOnline) {
        await OfflineSyncManager.instance.forceSync();
      }
      
      // Generate performance report
      perf.PerformanceMonitor.instance.recordMetric(perf.PerformanceMetric(
        id: 'forced_check_${DateTime.now().millisecondsSinceEpoch}',
        type: perf.MetricType.memoryUsage,
        value: DateTime.now().millisecondsSinceEpoch.toDouble(),
        unit: 'timestamp',
        severity: perf.PerformanceSeverity.good,
        category: 'maintenance',
      ));
      
      AppLogger.info('✅ Forced optimization check completed');
    } catch (e) {
      AppLogger.error('Forced optimization check failed: $e');
    }
  }
  
  /// Cleanup and dispose all optimization systems
  Future<void> dispose() async {
    try {
      AppLogger.info('🧹 Disposing optimization systems...');
      
      // Dispose in reverse order of initialization
      perf.PerformanceMonitor.instance.dispose();
      perf.AnalyticsManager.instance.dispose();
      OfflineSyncManager.instance.dispose();
      OptimizedCacheManager.instance.dispose();
      SecurityMonitor.instance.dispose();
      
      _isInitialized = false;
      AppLogger.info('✅ All optimization systems disposed');
    } catch (e) {
      AppLogger.error('Error during optimization system disposal: $e');
    }
  }
  
  /// Check if all systems are initialized and healthy
  bool get isHealthy {
    if (!_isInitialized) return false;
    
    try {
      // Basic health checks
      final cacheStats = OptimizedCacheManager.instance.getStats();
      final hitRate = cacheStats['hitRate'] ?? 0.0;
      
      // Consider system healthy if cache hit rate > 50%
      return hitRate > 0.5;
    } catch (e) {
      return false;
    }
  }
}

/// Convenience class for easy optimization integration
class Optimizations {
  /// Initialize all optimization systems - call this in main()
  static Future<void> initialize() async {
    await OptimizationManager.instance.initializeAll();
  }
  
  /// Get comprehensive system status
  static Map<String, dynamic> getStatus() {
    return OptimizationManager.instance.getSystemStatus();
  }
  
  /// Force optimization check and cleanup
  static Future<void> optimize() async {
    await OptimizationManager.instance.forceOptimizationCheck();
  }
  
  /// Check if optimization systems are healthy
  static bool get isHealthy => OptimizationManager.instance.isHealthy;
  
  /// Dispose all optimization systems
  static Future<void> dispose() async {
    await OptimizationManager.instance.dispose();
  }
}