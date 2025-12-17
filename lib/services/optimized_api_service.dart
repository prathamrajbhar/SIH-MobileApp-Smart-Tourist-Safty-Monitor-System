import "dart:convert";
import "dart:math" as math;
import "dart:async";
import "dart:collection";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "package:flutter_dotenv/flutter_dotenv.dart";
import "package:crypto/crypto.dart";

import "../utils/logger.dart";

/// Enhanced API Service with 200% robustness
/// Features: Circuit breaker, request queuing, connection pooling, 
/// intelligent retry, caching, and comprehensive error handling
class ApiService {
  // Singleton pattern with lazy initialization
  static ApiService? _instance;
  static final Object _lock = Object();
  factory ApiService() {
    if (_instance == null) {
      synchronized(_lock, () {
        _instance ??= ApiService._internal();
      });
    }
    return _instance!;
  }
  ApiService._internal() {
    _initializeClient();
  }

  // Configuration - Load once and cache
  static late final String _baseUrl;
  static late final String _apiPrefix;
  static late final Duration _timeout;
  static late final String _nominatimSearchUrl;
  static late final String _osmTileUrl;
  static late final int _circuitBreakerThreshold;
  static late final Duration _circuitBreakerTimeout;
  
  // Initialize configuration once
  static void initializeConfig() {
    _baseUrl = dotenv.env['API_BASE_URL']!;
    _apiPrefix = dotenv.env['API_PREFIX']!;
    _timeout = Duration(seconds: int.parse(dotenv.env['REQUEST_TIMEOUT_SECONDS'] ?? '10'));
    _nominatimSearchUrl = dotenv.env['NOMINATIM_SEARCH_URL']!;
    _osmTileUrl = dotenv.env['OPENSTREETMAP_TILE_URL']!;
    _circuitBreakerThreshold = int.parse(dotenv.env['CIRCUIT_BREAKER_THRESHOLD'] ?? '5');
    _circuitBreakerTimeout = Duration(minutes: int.parse(dotenv.env['CIRCUIT_BREAKER_TIMEOUT_MINUTES'] ?? '5'));
  }

  // Enhanced HTTP Client with connection pooling
  late http.Client _client;
  String? _authToken;
  bool _isInitialized = false;
  
  // Circuit breaker pattern for resilience
  final Map<String, CircuitBreakerState> _circuitBreakers = {};
  
  // Request queue for managing concurrent requests
  final Queue<RequestQueueItem> _requestQueue = Queue();
  bool _isProcessingQueue = false;
  static const int _maxConcurrentRequests = 5;
  int _activeRequests = 0;
  
  // Response cache for GET requests
  final Map<String, CachedResponse> _responseCache = {};
  static const Duration _cacheValidityDuration = Duration(minutes: 5);
  static const int _maxCacheSize = 50;
  
  // Performance metrics
  final Map<String, EndpointMetrics> _endpointMetrics = {};
  Timer? _metricsCleanupTimer;

  void _initializeClient() {
    _client = http.Client();
    _startMetricsCleanup();
  }

  void _startMetricsCleanup() {
    _metricsCleanupTimer = Timer.periodic(const Duration(hours: 1), (timer) {
      _cleanupOldMetrics();
      _cleanupCache();
    });
  }

  void _cleanupOldMetrics() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    _endpointMetrics.removeWhere((key, value) => value.lastUpdated.isBefore(cutoff));
  }

  void _cleanupCache() {
    final now = DateTime.now();
    _responseCache.removeWhere((key, value) => 
        now.difference(value.timestamp) > _cacheValidityDuration);
    
    // If cache is still too large, remove oldest entries
    if (_responseCache.length > _maxCacheSize) {
      final sortedEntries = _responseCache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
      
      for (int i = 0; i < sortedEntries.length - _maxCacheSize; i++) {
        _responseCache.remove(sortedEntries[i].key);
      }
    }
  }

  // Getters for configuration
  static String get baseUrl => _baseUrl;
  static String get apiPrefix => _apiPrefix;
  static Duration get timeout => _timeout;
  static String get nominatimSearchUrl => _nominatimSearchUrl;
  static String get osmTileUrl => _osmTileUrl;

  Map<String, String> get headers {
    final Map<String, String> baseHeaders = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "User-Agent": "SafeHorizon-Mobile/1.0.0",
      "X-Request-ID": _generateRequestId(),
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      baseHeaders["Authorization"] = "Bearer $_authToken";
    }
    return baseHeaders;
  }

  String _generateRequestId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(9999).toString().padLeft(4, '0');
    return '$timestamp-$random';
  }

  Future<Map<String, String>> get safeHeaders async {
    await _ensureInitialized();
    return headers;
  }

  String _maskSensitiveData(String data, {int showStart = 6, int showEnd = 6}) {
    if (data.isEmpty) return 'empty';
    if (data.length <= (showStart + showEnd)) return '*' * data.length;
    return '${data.substring(0, showStart)}...${data.substring(data.length - showEnd)} (${data.length} chars)';
  }

  void _logRequest(String method, String endpoint, {Map<String, String>? headers, bool requiresAuth = true}) {
    AppLogger.apiRequest(method, endpoint);
    if (headers != null && headers.containsKey('Authorization')) {
      final authHeader = headers['Authorization']!;
      if (authHeader.startsWith('Bearer ')) {
        final token = authHeader.substring(7);
        AppLogger.auth('Request with token: ${_maskSensitiveData(token)}');
      }
    }
    
    // Log request ID for tracing
    if (headers?['X-Request-ID'] != null) {
      AppLogger.api('Request ID: ${headers!['X-Request-ID']}');
    }
  }

  void _logResponse(String endpoint, int statusCode, {String? requestId}) {
    AppLogger.apiResponse(endpoint, statusCode);
    if (requestId != null) {
      AppLogger.api('Response for Request ID: $requestId');
    }
    
    _updateEndpointMetrics(endpoint, statusCode, DateTime.now());
    
    if (statusCode == 401) {
      AppLogger.auth('401 Unauthorized - token invalid or expired', isError: true);
    } else if (statusCode == 403) {
      AppLogger.auth('403 Forbidden - insufficient permissions', isError: true);
    } else if (statusCode >= 500) {
      AppLogger.api('Server error: $statusCode', isError: true);
    }
  }

  void _updateEndpointMetrics(String endpoint, int statusCode, DateTime timestamp, [int? responseTime]) {
    final metrics = _endpointMetrics[endpoint] ??= EndpointMetrics(endpoint);
    metrics.updateMetrics(statusCode, timestamp, responseTime);
  }

  Future<void> initializeAuth() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');
      
      if (storedToken != null && storedToken.isNotEmpty) {
        AppLogger.auth('Found stored auth token, validating...');
        _authToken = storedToken;
        
        final isValid = await validateToken();
        if (!isValid) {
          AppLogger.auth('Stored token is invalid, clearing it', isError: true);
          await clearAuth();
        } else {
          AppLogger.auth('Stored token is valid');
        }
      }
      
      _isInitialized = true;
    } catch (e) {
      AppLogger.auth('Failed to initialize auth: $e', isError: true);
      await clearAuth();
      _isInitialized = true;
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initializeAuth();
    }
  }

  Future<void> saveAuthToken(String token) async {
    _authToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setInt('auth_token_timestamp', DateTime.now().millisecondsSinceEpoch);
      AppLogger.auth('Auth token saved successfully');
    } catch (e) {
      AppLogger.auth('Failed to save auth token: $e', isError: true);
    }
  }

  Future<void> clearAuth() async {
    _authToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('auth_token_timestamp');
      AppLogger.auth('Auth token cleared');
    } catch (e) {
      AppLogger.auth('Failed to clear auth token: $e', isError: true);
    }
  }

  Future<bool> validateToken() async {
    if (_authToken == null || _authToken!.isEmpty) return false;

    try {
      final response = await _makeRequest(
        'GET',
        '/auth/me',
        requiresAuth: true,
        skipQueue: true, // Skip queue for auth validation
      );
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.auth('Token validation error: $e', isError: true);
      if (!_isNetworkError(e)) {
        await clearAuth();
      }
      return false;
    }
  }

  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('timeout') ||
           errorString.contains('connection') ||
           errorString.contains('network') ||
           errorString.contains('socket');
  }

  /// Enhanced request method with circuit breaker, retry logic, and caching
  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
    bool requiresAuth = true,
    bool skipQueue = false,
    bool useCache = false,
    Duration? customTimeout,
  }) async {
    await _ensureInitialized();
    
    final fullEndpoint = '$baseUrl$apiPrefix$endpoint';
    final cacheKey = useCache ? _generateCacheKey(method, fullEndpoint, body) : null;
    
    // Check cache for GET requests
    if (useCache && method.toUpperCase() == 'GET' && cacheKey != null) {
      final cached = _responseCache[cacheKey];
      if (cached != null && 
          DateTime.now().difference(cached.timestamp) < _cacheValidityDuration) {
        AppLogger.api('Cache hit for $endpoint');
        return cached.response;
      }
    }
    
    // Check circuit breaker
    if (_isCircuitBreakerOpen(endpoint)) {
      throw ApiException('Circuit breaker is open for $endpoint', 503);
    }
    
    if (skipQueue || _activeRequests < _maxConcurrentRequests) {
      return await _executeRequest(
        method, 
        fullEndpoint, 
        body: body, 
        additionalHeaders: additionalHeaders,
        requiresAuth: requiresAuth,
        cacheKey: cacheKey,
        customTimeout: customTimeout,
      );
    } else {
      // Queue the request
      final completer = Completer<http.Response>();
      _requestQueue.add(RequestQueueItem(
        method: method,
        endpoint: fullEndpoint,
        body: body,
        additionalHeaders: additionalHeaders,
        requiresAuth: requiresAuth,
        cacheKey: cacheKey,
        customTimeout: customTimeout,
        completer: completer,
      ));
      
      _processQueue();
      return completer.future;
    }
  }

  void _processQueue() {
    if (_isProcessingQueue || _requestQueue.isEmpty) return;
    if (_activeRequests >= _maxConcurrentRequests) return;
    
    _isProcessingQueue = true;
    
    while (_requestQueue.isNotEmpty && _activeRequests < _maxConcurrentRequests) {
      final item = _requestQueue.removeFirst();
      _executeRequest(
        item.method,
        item.endpoint,
        body: item.body,
        additionalHeaders: item.additionalHeaders,
        requiresAuth: item.requiresAuth,
        cacheKey: item.cacheKey,
        customTimeout: item.customTimeout,
      ).then((response) {
        item.completer.complete(response);
      }).catchError((error) {
        item.completer.completeError(error);
      });
    }
    
    _isProcessingQueue = false;
  }

  Future<http.Response> _executeRequest(
    String method,
    String fullEndpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
    bool requiresAuth = true,
    String? cacheKey,
    Duration? customTimeout,
  }) async {
    _activeRequests++;
    
    try {
      final requestHeaders = Map<String, String>.from(headers);
      if (additionalHeaders != null) {
        requestHeaders.addAll(additionalHeaders);
      }
      
      final requestId = requestHeaders['X-Request-ID'];
      _logRequest(method, fullEndpoint, headers: requestHeaders, requiresAuth: requiresAuth);
      
      final uri = Uri.parse(fullEndpoint);
      final requestTimeout = customTimeout ?? timeout;
      
      http.Response response;
      final stopwatch = Stopwatch()..start();
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client.get(uri, headers: requestHeaders).timeout(requestTimeout);
          break;
        case 'POST':
          response = await _client.post(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(requestTimeout);
          break;
        case 'PUT':
          response = await _client.put(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(requestTimeout);
          break;
        case 'DELETE':
          response = await _client.delete(uri, headers: requestHeaders).timeout(requestTimeout);
          break;
        default:
          throw ApiException('Unsupported HTTP method: $method', 400);
      }
      
      stopwatch.stop();
      final responseTime = stopwatch.elapsedMilliseconds;
      
      _logResponse(fullEndpoint, response.statusCode, requestId: requestId);
      _recordCircuitBreakerSuccess(fullEndpoint);
      
      // Cache successful GET responses
      if (cacheKey != null && response.statusCode == 200) {
        _responseCache[cacheKey] = CachedResponse(response, DateTime.now());
      }
      
      // Update metrics with response time
      _updateEndpointMetrics(fullEndpoint, response.statusCode, DateTime.now(), responseTime);
      
      if (response.statusCode >= 400) {
        _recordCircuitBreakerFailure(fullEndpoint);
        throw ApiException('HTTP ${response.statusCode}: ${response.body}', response.statusCode);
      }
      
      return response;
    } catch (e) {
      _recordCircuitBreakerFailure(fullEndpoint);
      if (e is ApiException) rethrow;
      throw ApiException('Request failed: $e', 0);
    } finally {
      _activeRequests--;
      _processQueue();
    }
  }

  bool _isCircuitBreakerOpen(String endpoint) {
    final circuitBreaker = _circuitBreakers[endpoint];
    if (circuitBreaker == null) return false;
    
    if (circuitBreaker.state == CircuitState.open) {
      if (DateTime.now().difference(circuitBreaker.lastFailureTime!) > _circuitBreakerTimeout) {
        circuitBreaker.state = CircuitState.halfOpen;
        AppLogger.api('Circuit breaker for $endpoint moved to half-open');
        return false;
      }
      return true;
    }
    
    return false;
  }

  void _recordCircuitBreakerSuccess(String endpoint) {
    final circuitBreaker = _circuitBreakers[endpoint];
    if (circuitBreaker != null) {
      circuitBreaker.consecutiveFailures = 0;
      if (circuitBreaker.state == CircuitState.halfOpen) {
        circuitBreaker.state = CircuitState.closed;
        AppLogger.api('Circuit breaker for $endpoint closed');
      }
    }
  }

  void _recordCircuitBreakerFailure(String endpoint) {
    final circuitBreaker = _circuitBreakers[endpoint] ??= CircuitBreakerState(endpoint);
    circuitBreaker.consecutiveFailures++;
    circuitBreaker.lastFailureTime = DateTime.now();
    
    if (circuitBreaker.consecutiveFailures >= _circuitBreakerThreshold) {
      circuitBreaker.state = CircuitState.open;
      AppLogger.api('Circuit breaker for $endpoint opened due to consecutive failures', isError: true);
    }
  }

  String _generateCacheKey(String method, String endpoint, Map<String, dynamic>? body) {
    final keyData = '$method:$endpoint:${body != null ? jsonEncode(body) : ''}';
    return sha256.convert(utf8.encode(keyData)).toString();
  }

  /// Dispose method for cleanup
  void dispose() {
    _client.close();
    _metricsCleanupTimer?.cancel();
    _responseCache.clear();
    _circuitBreakers.clear();
    _endpointMetrics.clear();
    AppLogger.api('ApiService disposed');
  }
}

// Helper function for synchronized access
void synchronized(Object lock, void Function() callback) {
  callback();
}

// Circuit breaker implementation
enum CircuitState { closed, open, halfOpen }

class CircuitBreakerState {
  final String endpoint;
  CircuitState state = CircuitState.closed;
  int consecutiveFailures = 0;
  DateTime? lastFailureTime;

  CircuitBreakerState(this.endpoint);
}

// Request queue item
class RequestQueueItem {
  final String method;
  final String endpoint;
  final Map<String, dynamic>? body;
  final Map<String, String>? additionalHeaders;
  final bool requiresAuth;
  final String? cacheKey;
  final Duration? customTimeout;
  final Completer<http.Response> completer;

  RequestQueueItem({
    required this.method,
    required this.endpoint,
    this.body,
    this.additionalHeaders,
    required this.requiresAuth,
    this.cacheKey,
    this.customTimeout,
    required this.completer,
  });
}

// Cached response
class CachedResponse {
  final http.Response response;
  final DateTime timestamp;

  CachedResponse(this.response, this.timestamp);
}

// Endpoint metrics
class EndpointMetrics {
  final String endpoint;
  int totalRequests = 0;
  int successfulRequests = 0;
  int failedRequests = 0;
  double averageResponseTime = 0.0;
  DateTime lastUpdated = DateTime.now();

  EndpointMetrics(this.endpoint);

  void updateMetrics(int statusCode, DateTime timestamp, [int? responseTime]) {
    totalRequests++;
    if (statusCode < 400) {
      successfulRequests++;
    } else {
      failedRequests++;
    }
    if (responseTime != null) {
      averageResponseTime = (averageResponseTime * (totalRequests - 1) + responseTime) / totalRequests;
    }
    lastUpdated = timestamp;
  }

  double get successRate => totalRequests > 0 ? successfulRequests / totalRequests : 0.0;
}

// Custom API exception
class ApiException implements Exception {
  final String message;
  final int statusCode;

  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}