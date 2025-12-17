import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/logger.dart';

/// Comprehensive error handling and resilience framework for 200% robustness
/// Features: Circuit breakers, retry mechanisms, graceful degradation, 
/// error boundaries, and intelligent failure recovery

/// Base exception class for the application
abstract class SafeHorizonException implements Exception {
  final String message;
  final String code;
  final DateTime timestamp;
  final Map<String, dynamic> context;
  
  SafeHorizonException(this.message, this.code, [Map<String, dynamic>? context])
      : context = context ?? {},
        timestamp = DateTime.now();

  @override
  String toString() => 'SafeHorizonException($code): $message';
  
  Map<String, dynamic> toJson() => {
    'message': message,
    'code': code,
    'timestamp': timestamp.toIso8601String(),
    'context': context,
  };
}

/// Network-related exceptions
class NetworkException extends SafeHorizonException {
  final int? statusCode;
  final bool isRetryable;
  
  NetworkException(
    String message, 
    String code, {
    this.statusCode,
    this.isRetryable = true,
    Map<String, dynamic>? context,
  }) : super(message, code, context);
}

/// Location service exceptions
class LocationException extends SafeHorizonException {
  final LocationErrorSeverity severity;
  
  LocationException(
    String message, 
    String code, 
    this.severity, 
    [Map<String, dynamic>? context]
  ) : super(message, code, context);
}

/// Authentication exceptions
class AuthException extends SafeHorizonException {
  final bool requiresReauth;
  
  AuthException(
    String message, 
    String code, 
    this.requiresReauth, 
    [Map<String, dynamic>? context]
  ) : super(message, code, context);
}

/// Business logic exceptions
class BusinessLogicException extends SafeHorizonException {
  final String userMessage;
  
  BusinessLogicException(
    String message, 
    String code, 
    this.userMessage, 
    [Map<String, dynamic>? context]
  ) : super(message, code, context);
}

enum LocationErrorSeverity { low, medium, high, critical }

/// Circuit breaker implementation for service reliability
class CircuitBreaker {
  final String name;
  final int failureThreshold;
  final Duration timeout;
  final Duration retryDelay;
  
  CircuitBreakerState _state = CircuitBreakerState.closed;
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  DateTime? _nextRetryTime;
  
  CircuitBreaker({
    required this.name,
    this.failureThreshold = 5,
    this.timeout = const Duration(minutes: 5),
    this.retryDelay = const Duration(seconds: 30),
  });
  
  CircuitBreakerState get state => _state;
  int get failureCount => _failureCount;
  bool get isOpen => _state == CircuitBreakerState.open;
  bool get isHalfOpen => _state == CircuitBreakerState.halfOpen;
  bool get isClosed => _state == CircuitBreakerState.closed;
  
  Future<T> execute<T>(Future<T> Function() operation) async {
    if (_shouldReject()) {
      throw NetworkException(
        'Circuit breaker is open for $name',
        'CIRCUIT_BREAKER_OPEN',
        statusCode: 503,
        isRetryable: false,
        context: {'circuitBreaker': name, 'failureCount': _failureCount},
      );
    }
    
    try {
      final result = await operation();
      _onSuccess();
      return result;
    } catch (e) {
      _onFailure();
      rethrow;
    }
  }
  
  bool _shouldReject() {
    final now = DateTime.now();
    
    switch (_state) {
      case CircuitBreakerState.closed:
        return false;
      case CircuitBreakerState.open:
        if (_nextRetryTime != null && now.isAfter(_nextRetryTime!)) {
          _state = CircuitBreakerState.halfOpen;
          AppLogger.info('Circuit breaker $name moved to half-open state');
          return false;
        }
        return true;
      case CircuitBreakerState.halfOpen:
        return false;
    }
  }
  
  void _onSuccess() {
    _failureCount = 0;
    _lastFailureTime = null;
    _nextRetryTime = null;
    
    if (_state == CircuitBreakerState.halfOpen) {
      _state = CircuitBreakerState.closed;
      AppLogger.info('Circuit breaker $name closed after successful operation');
    }
  }
  
  void _onFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
      _nextRetryTime = DateTime.now().add(retryDelay);
      AppLogger.error(
        'Circuit breaker $name opened after $failureCount failures'
      );
    }
  }
  
  void reset() {
    _state = CircuitBreakerState.closed;
    _failureCount = 0;
    _lastFailureTime = null;
    _nextRetryTime = null;
    AppLogger.info('Circuit breaker $name manually reset');
  }
  
  Map<String, dynamic> getMetrics() => {
    'name': name,
    'state': _state.toString(),
    'failureCount': _failureCount,
    'lastFailureTime': _lastFailureTime?.toIso8601String(),
    'nextRetryTime': _nextRetryTime?.toIso8601String(),
  };
}

enum CircuitBreakerState { closed, open, halfOpen }

/// Retry mechanism with exponential backoff and jitter
class RetryPolicy {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool useJitter;
  final List<Type> retryableExceptions;
  
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(minutes: 5),
    this.useJitter = true,
    this.retryableExceptions = const [NetworkException],
  });
  
  static const RetryPolicy conservative = RetryPolicy(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 2),
    backoffMultiplier: 1.5,
  );
  
  static const RetryPolicy aggressive = RetryPolicy(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 500),
    backoffMultiplier: 2.0,
  );
  
  static const RetryPolicy none = RetryPolicy(maxAttempts: 1);
  
  Future<T> execute<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    int attempt = 0;
    Duration delay = initialDelay;
    
    while (true) {
      attempt++;
      
      try {
        final stopwatch = Stopwatch()..start();
        final result = await operation();
        stopwatch.stop();
        
        if (attempt > 1) {
          AppLogger.info(
            'Operation $operationName succeeded on attempt $attempt (${stopwatch.elapsedMilliseconds}ms)'
          );
        }
        
        return result;
      } catch (e) {
        final isRetryable = _isRetryableException(e);
        final hasAttemptsLeft = attempt < maxAttempts;
        
        AppLogger.error(
          'Operation $operationName failed on attempt $attempt: $e (retryable: $isRetryable, hasAttemptsLeft: $hasAttemptsLeft)'
        );
        
        if (!isRetryable || !hasAttemptsLeft) {
          rethrow;
        }
        
        // Calculate delay with exponential backoff and jitter
        final actualDelay = _calculateDelay(delay);
        AppLogger.info(
          'Retrying $operationName in ${actualDelay.inMilliseconds}ms (attempt ${attempt + 1}/$maxAttempts)'
        );
        
        await Future.delayed(actualDelay);
        delay = Duration(
          milliseconds: math.min(
            (delay.inMilliseconds * backoffMultiplier).round(),
            maxDelay.inMilliseconds,
          ),
        );
      }
    }
  }
  
  bool _isRetryableException(dynamic exception) {
    if (exception is NetworkException) {
      return exception.isRetryable;
    }
    
    return retryableExceptions.any((type) => exception.runtimeType == type) ||
           _isTransientError(exception);
  }
  
  bool _isTransientError(dynamic exception) {
    final errorString = exception.toString().toLowerCase();
    return errorString.contains('timeout') ||
           errorString.contains('connection') ||
           errorString.contains('network') ||
           errorString.contains('socket') ||
           errorString.contains('unreachable');
  }
  
  Duration _calculateDelay(Duration baseDelay) {
    if (!useJitter) return baseDelay;
    
    // Add jitter to prevent thundering herd
    final jitterMs = math.Random().nextInt(baseDelay.inMilliseconds ~/ 2);
    return Duration(milliseconds: baseDelay.inMilliseconds + jitterMs);
  }
}

/// Fallback mechanism for graceful degradation
class FallbackHandler<T> {
  final String name;
  final T Function()? fallbackValue;
  final Future<T> Function()? fallbackOperation;
  final bool logFallback;
  
  FallbackHandler({
    required this.name,
    this.fallbackValue,
    this.fallbackOperation,
    this.logFallback = true,
  }) : assert(fallbackValue != null || fallbackOperation != null,
              'Either fallbackValue or fallbackOperation must be provided');
  
  Future<T> execute(Future<T> Function() primaryOperation) async {
    try {
      return await primaryOperation();
    } catch (e) {
      if (logFallback) {
        AppLogger.error(
          'Primary operation for $name failed, executing fallback: $e'
        );
      }
      
      if (fallbackOperation != null) {
        try {
          final result = await fallbackOperation!();
          AppLogger.info('Fallback operation for $name succeeded');
          return result;
        } catch (fallbackError) {
          AppLogger.error(
            'Fallback operation for $name also failed: $fallbackError'
          );
          if (fallbackValue != null) {
            AppLogger.info('Using static fallback value for $name');
            return fallbackValue!();
          }
          rethrow;
        }
      } else {
        AppLogger.info('Using static fallback value for $name');
        return fallbackValue!();
      }
    }
  }
}

/// Error boundary for UI components
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace stackTrace)? errorBuilder;
  final void Function(Object error, StackTrace stackTrace)? onError;
  final String? name;
  
  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
    this.onError,
    this.name,
  });
  
  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;
  
  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!, _stackTrace!) ??
             _buildDefaultErrorWidget();
    }
    
    return widget.child;
  }
  
  Widget _buildDefaultErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.red.shade50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            kDebugMode ? _error.toString() : 'Please try again later',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade600),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {
              _error = null;
              _stackTrace = null;
            }),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  void _handleError(Object error, StackTrace stackTrace) {
    setState(() {
      _error = error;
      _stackTrace = stackTrace;
    });
    
    final boundaryName = widget.name ?? 'Unknown';
    AppLogger.error('Error boundary $boundaryName caught error: $error');
    
    // Report to crash analytics
    ErrorReporter.instance.reportError(error, stackTrace, {
      'errorBoundary': boundaryName,
      'widget': widget.child.runtimeType.toString(),
    });
    
    widget.onError?.call(error, stackTrace);
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ErrorWidget.builder = (FlutterErrorDetails details) {
      _handleError(details.exception, details.stack ?? StackTrace.current);
      return _buildDefaultErrorWidget();
    };
  }
}

/// Global error reporter for crash analytics and monitoring
class ErrorReporter {
  static ErrorReporter? _instance;
  static ErrorReporter get instance => _instance ??= ErrorReporter._internal();
  ErrorReporter._internal();
  
  final List<ErrorReport> _errorHistory = [];
  static const int _maxErrorHistory = 100;
  Timer? _uploadTimer;
  
  void initialize() {
    // Set up global error handlers
    FlutterError.onError = (FlutterErrorDetails details) {
      reportError(details.exception, details.stack, {
        'context': details.context?.toString(),
        'library': details.library,
        'informationCollector': details.informationCollector?.toString(),
      });
    };
    
    // Handle platform errors
    PlatformDispatcher.instance.onError = (error, stack) {
      reportError(error, stack, {'platform': 'dart'});
      return true;
    };
    
    // Periodic upload of error reports
    _uploadTimer = Timer.periodic(const Duration(minutes: 15), (timer) {
      _uploadErrorReports();
    });
    
    AppLogger.info('Error reporter initialized');
  }
  
  void reportError(
    Object error, 
    StackTrace? stackTrace, 
    [Map<String, dynamic>? context]
  ) {
    final report = ErrorReport(
      error: error,
      stackTrace: stackTrace ?? StackTrace.current,
      context: context ?? {},
      timestamp: DateTime.now(),
    );
    
    _errorHistory.add(report);
    
    // Keep only recent errors
    if (_errorHistory.length > _maxErrorHistory) {
      _errorHistory.removeAt(0);
    }
    
    // Log error
    AppLogger.error('Error reported: ${error.toString()}');
    
    // For critical errors, try immediate upload
    if (_isCriticalError(error)) {
      _uploadErrorReports();
    }
  }
  
  bool _isCriticalError(Object error) {
    if (error is SafeHorizonException) {
      return error.code.contains('CRITICAL') || 
             error.code.contains('SECURITY') ||
             error.code.contains('AUTH_FAILURE');
    }
    
    final errorString = error.toString().toLowerCase();
    return errorString.contains('security') ||
           errorString.contains('authentication') ||
           errorString.contains('authorization');
  }
  
  Future<void> _uploadErrorReports() async {
    if (_errorHistory.isEmpty) return;
    
    try {
      // In a real implementation, this would upload to a crash reporting service
      // For now, we'll just save to local storage
      final prefs = await SharedPreferences.getInstance();
      final errorData = _errorHistory.map((e) => e.toJson()).toList();
      await prefs.setString('error_reports', jsonEncode(errorData));
      
      AppLogger.info('Uploaded ${_errorHistory.length} error reports');
      _errorHistory.clear();
    } catch (e) {
      AppLogger.error('Failed to upload error reports: $e');
    }
  }
  
  List<ErrorReport> getRecentErrors() => List.unmodifiable(_errorHistory);
  
  void dispose() {
    _uploadTimer?.cancel();
    _uploadErrorReports();
  }
}

/// Error report data structure
class ErrorReport {
  final Object error;
  final StackTrace stackTrace;
  final Map<String, dynamic> context;
  final DateTime timestamp;
  
  ErrorReport({
    required this.error,
    required this.stackTrace,
    required this.context,
    required this.timestamp,
  });
  
  Map<String, dynamic> toJson() => {
    'error': error.toString(),
    'stackTrace': stackTrace.toString(),
    'context': context,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Health check system for monitoring service status
class HealthCheckManager {
  static HealthCheckManager? _instance;
  static HealthCheckManager get instance => _instance ??= HealthCheckManager._internal();
  HealthCheckManager._internal();
  
  final Map<String, HealthCheck> _healthChecks = {};
  Timer? _healthCheckTimer;
  
  void initialize() {
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      _runHealthChecks();
    });
  }
  
  void registerHealthCheck(String name, HealthCheck healthCheck) {
    _healthChecks[name] = healthCheck;
    AppLogger.info('Registered health check: $name');
  }
  
  void unregisterHealthCheck(String name) {
    _healthChecks.remove(name);
    AppLogger.info('Unregistered health check: $name');
  }
  
  Future<Map<String, HealthStatus>> _runHealthChecks() async {
    final results = <String, HealthStatus>{};
    
    for (final entry in _healthChecks.entries) {
      try {
        final status = await entry.value.check();
        results[entry.key] = status;
        
        if (!status.isHealthy) {
          AppLogger.error(
            'Health check failed for ${entry.key}: ${status.message}'
          );
        }
      } catch (e) {
        results[entry.key] = HealthStatus.unhealthy('Health check failed: $e');
        AppLogger.error(
          'Health check error for ${entry.key}: $e'
        );
      }
    }
    
    return results;
  }
  
  Future<Map<String, HealthStatus>> getHealthStatus() => _runHealthChecks();
  
  void dispose() {
    _healthCheckTimer?.cancel();
  }
}

/// Health check interface
abstract class HealthCheck {
  Future<HealthStatus> check();
}

/// Health status result
class HealthStatus {
  final bool isHealthy;
  final String message;
  final Map<String, dynamic> details;
  final DateTime timestamp;
  
  HealthStatus.healthy([String? message, Map<String, dynamic>? details])
      : isHealthy = true,
        message = message ?? 'Service is healthy',
        details = details ?? {},
        timestamp = DateTime.now();
  
  HealthStatus.unhealthy(String message, [Map<String, dynamic>? details])
      : isHealthy = false,
        message = message,
        details = details ?? {},
        timestamp = DateTime.now();
  
  Map<String, dynamic> toJson() => {
    'isHealthy': isHealthy,
    'message': message,
    'details': details,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Extensions for enhanced resilience patterns
extension ResilienceExtensions on Future {
  Future<T> withCircuitBreaker<T>(CircuitBreaker circuitBreaker) async {
    return circuitBreaker.execute(() => this as Future<T>);
  }
  
  Future<T> withRetry<T>(RetryPolicy policy, String operationName) async {
    return policy.execute(operationName, () => this as Future<T>);
  }
  
  Future<T> withFallback<T>(FallbackHandler<T> fallback) async {
    return fallback.execute(() => this as Future<T>);
  }
  
  Future<T> withTimeout<T>(Duration timeout, [String? operation]) async {
    try {
      return await (this as Future<T>).timeout(timeout);
    } on TimeoutException {
      throw NetworkException(
        'Operation timed out after ${timeout.inSeconds}s',
        'OPERATION_TIMEOUT',
        context: {'operation': operation, 'timeoutSeconds': timeout.inSeconds},
      );
    }
  }
}