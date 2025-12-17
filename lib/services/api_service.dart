import "dart:convert";
import "dart:io";
import "dart:math" as math;
import "dart:collection";
import "dart:async";
import "package:http/http.dart" as http;
import "package:shared_preferences/shared_preferences.dart";
import "package:flutter_dotenv/flutter_dotenv.dart";

import "../models/geospatial_heat.dart";
import "../models/alert.dart";
import "../utils/logger.dart";

/// Industry-grade API service with connection pooling, caching, and resilience patterns
class ApiService {
  // Singleton pattern to ensure only one instance throughout the app
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initializeConnectionPool();
    _initializeCache();
  }

  // Load configuration from .env file - required values
  static String get baseUrl => dotenv.env['API_BASE_URL']!;
  static String get apiPrefix => dotenv.env['API_PREFIX']!;
  static Duration get timeout => Duration(seconds: int.parse(dotenv.env['REQUEST_TIMEOUT_SECONDS']!));
  static bool get debugMode => dotenv.env['DEBUG_MODE']?.toLowerCase() == 'true';
  
  // External service URLs
  static String get nominatimSearchUrl => dotenv.env['NOMINATIM_SEARCH_URL']!;
  static String get osmTileUrl => dotenv.env['OPENSTREETMAP_TILE_URL']!;
  
  // Optimized connection management
  late final http.Client _client;
  String? _authToken;
  bool _isInitialized = false;
  
  // Circuit breaker pattern for resilience
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  static const int _failureThreshold = 3;
  static const Duration _circuitBreakerTimeout = Duration(minutes: 2);
  
  // Request batching and caching
  final Map<String, dynamic> _responseCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  final Queue<Map<String, dynamic>> _requestQueue = Queue();
  Timer? _batchTimer;
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const Duration _batchDelay = Duration(milliseconds: 100);
  
  // Performance monitoring
  final Map<String, List<int>> _responseTimeStats = {};

  /// Initialize optimized HTTP client with connection pooling
  void _initializeConnectionPool() {
    _client = http.Client();
    // Connection pooling is handled by the underlying HTTP client
    AppLogger.api('🔗 Connection pool initialized');
  }
  
  /// Initialize response cache
  void _initializeCache() {
    // Cache is initialized as empty map
    AppLogger.api('💾 Response cache initialized');
  }
  
  /// Get headers with proper authentication
  Map<String, String> get headers {
    final Map<String, String> baseHeaders = {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "User-Agent": "SafeHorizon-Mobile/1.0",
    };
    if (_authToken != null && _authToken!.isNotEmpty) {
      baseHeaders["Authorization"] = "Bearer $_authToken";
    }
    return baseHeaders;
  }

  // Safer headers that ensure auth initialization
  Future<Map<String, String>> get safeHeaders async {
    await _ensureInitialized();
    final Map<String, String> baseHeaders = {"Content-Type": "application/json"};
    if (_authToken != null && _authToken!.isNotEmpty) {
      baseHeaders["Authorization"] = "Bearer $_authToken";
    }
    return baseHeaders;
  }

  // Helper to mask passwords for safe logging (never log plaintext)
  String _maskPassword(String password) {
    final masked = List.filled(password.length, '*').join();
    return '$masked (${password.length} chars)';
  }

  // Helper to mask tokens for safe logging (show first/last 6 chars)
  String _maskToken(String? token) {
    if (token == null || token.isEmpty) return 'null';
    if (token.length <= 12) return '*' * token.length;
    return '${token.substring(0, 6)}...${token.substring(token.length - 6)} (${token.length} chars)';
  }
  
  /// Circuit breaker pattern to handle service failures gracefully
  /// Pure function - only checks state, no side effects
  bool get _isCircuitBreakerOpen {
    if (_failureCount < _failureThreshold) return false;
    if (_lastFailureTime == null) return false;
    
    final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
    return timeSinceLastFailure <= _circuitBreakerTimeout;
  }
  
  /// Reset circuit breaker if timeout has expired
  void _resetCircuitBreakerIfExpired() {
    if (_failureCount >= _failureThreshold && _lastFailureTime != null) {
      final timeSinceLastFailure = DateTime.now().difference(_lastFailureTime!);
      if (timeSinceLastFailure > _circuitBreakerTimeout) {
        _failureCount = 0;
        _lastFailureTime = null;
        AppLogger.api('🔄 Circuit breaker reset after ${timeSinceLastFailure.inMinutes}m');
      }
    }
  }
  
  /// Record request failure for circuit breaker
  void _recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    AppLogger.api('⚠️ Request failure recorded (${_failureCount}/${_failureThreshold})');
    
    if (_failureCount >= _failureThreshold) {
      AppLogger.api('🚫 Circuit breaker opened - blocking requests');
    }
  }

  /// Execute request with circuit breaker protection
  Future<T> _executeWithCircuitBreaker<T>(
    String endpoint,
    Future<T> Function() request,
  ) async {
    // Reset circuit breaker if expired
    _resetCircuitBreakerIfExpired();
    
    // Check if circuit breaker is open
    if (_isCircuitBreakerOpen) {
      AppLogger.api('🚫 Circuit breaker is open, request blocked: $endpoint');
      throw HttpException('Service temporarily unavailable - circuit breaker is open');
    }
    
    try {
      final result = await request();
      // Reset failure count on success
      if (_failureCount > 0) {
        _failureCount = 0;
        _lastFailureTime = null;
        AppLogger.api('✅ Request succeeded, circuit breaker reset');
      }
      return result;
    } catch (e) {
      _recordFailure();
      rethrow;
    }
  }
  
  /// Check if cached response is still valid
  bool _isCacheValid(String cacheKey) {
    final timestamp = _cacheTimestamps[cacheKey];
    if (timestamp == null) return false;
    
    final age = DateTime.now().difference(timestamp);
    return age < _cacheExpiry;
  }
  
  /// Get cached response if available and valid
  T? _getCachedResponse<T>(String cacheKey) {
    if (!_isCacheValid(cacheKey)) {
      _responseCache.remove(cacheKey);
      _cacheTimestamps.remove(cacheKey);
      return null;
    }
    
    final cached = _responseCache[cacheKey];
    if (cached != null) {
      AppLogger.api('💾 Cache hit for $cacheKey');
    }
    return cached as T?;
  }
  
  /// Cache response with timestamp
  void _cacheResponse(String cacheKey, dynamic response) {
    _responseCache[cacheKey] = response;
    _cacheTimestamps[cacheKey] = DateTime.now();
    
    // Clean old cache entries periodically
    if (_responseCache.length > 100) {
      _cleanCache();
    }
  }
  
  /// Clean expired cache entries
  void _cleanCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    _cacheTimestamps.forEach((key, timestamp) {
      if (now.difference(timestamp) > _cacheExpiry) {
        expiredKeys.add(key);
      }
    });
    
    for (final key in expiredKeys) {
      _responseCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    AppLogger.api('🧹 Cleaned ${expiredKeys.length} expired cache entries');
  }

  // Enhanced request logging with masked token
  void _logRequest(String method, String endpoint, {Map<String, String>? headers, bool requiresAuth = true}) {
    AppLogger.apiRequest(method, endpoint);
    if (headers != null && headers.containsKey('Authorization')) {
      final authHeader = headers['Authorization']!;
      if (authHeader.startsWith('Bearer ')) {
        final token = authHeader.substring(7);
        AppLogger.auth('Request with token: ${_maskToken(token)}');
      }
    } else if (requiresAuth) {
      // Only log as error if auth is required for this endpoint
      AppLogger.auth('Request without authorization token', isError: true);
    } else {
      // For public endpoints like register/login
      AppLogger.auth('Public endpoint - no auth required');
    }
  }

  // Enhanced response logging with error details
  void _logResponse(String endpoint, int statusCode, {String? body, bool isError = false}) {
    AppLogger.apiResponse(endpoint, statusCode);
    if (statusCode == 401) {
      AppLogger.auth('401 Unauthorized - token invalid or expired', isError: true);
      if (body != null) AppLogger.auth('401 Response body: $body');
    } else if (statusCode == 403) {
      AppLogger.auth('403 Forbidden - insufficient permissions or invalid token', isError: true);
      if (body != null) AppLogger.auth('403 Response body: $body');
    } else if (isError && body != null) {
      AppLogger.api('Error response body: $body', isError: true);
    }
  }

  // Initialize authentication token from storage
  Future<void> initializeAuth() async {
    if (_isInitialized) {
      AppLogger.auth('Auth already initialized, skipping...');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedToken = prefs.getString('auth_token');
      
      if (storedToken != null && storedToken.isNotEmpty) {
        AppLogger.auth('Found stored auth token, validating...');
        _authToken = storedToken;
        
        // Validate the stored token
        final isValid = await validateToken();
        if (!isValid) {
          AppLogger.auth('Stored token is invalid, clearing it', isError: true);
          // clearAuth() is already called in validateToken() for invalid tokens
          AppLogger.auth('App will require fresh login');
        } else {
          AppLogger.auth('Stored token is valid and ready to use');
        }
      } else {
        AppLogger.auth('No existing auth token found');
      }
      
      _isInitialized = true;
    } catch (e) {
      AppLogger.auth('Failed to load auth token from storage: $e', isError: true);
      // Clear any potentially corrupted token data
      await clearAuth();
      _isInitialized = true;
    }
  }

  // Ensure authentication is initialized before making API calls
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initializeAuth();
    }
  }

  // Save authentication token to storage
  Future<void> _saveAuthToken(String token) async {
    _authToken = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      AppLogger.auth('Auth token saved to storage successfully');
    } catch (e) {
      AppLogger.auth('Failed to save auth token to storage', isError: true);
    }
  }

  // Clear authentication token
  Future<void> clearAuth() async {
    _authToken = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      AppLogger.auth('Auth token cleared from storage');
    } catch (e) {
      AppLogger.auth('Failed to clear auth token from storage', isError: true);
    }
  }

  // Validate current token and handle auth errors
  Future<bool> validateToken() async {
    if (_authToken == null || _authToken!.isEmpty) {
      AppLogger.auth('No token available for validation', isError: true);
      return false;
    }

    try {
      AppLogger.auth('Validating current token: ${_maskToken(_authToken)}');
      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/auth/me"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        AppLogger.auth('Token validation successful');
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        AppLogger.auth('Token validation failed - ${response.statusCode} ${response.statusCode == 401 ? 'Unauthorized' : 'Forbidden'} (token may be corrupted)', isError: true);
        await clearAuth(); // Clear invalid token
        return false;
      }

      AppLogger.auth('Token validation failed with status: ${response.statusCode}', isError: true);
      return false;
    } catch (e) {
      AppLogger.auth('Token validation error: $e', isError: true);
      // If validation fails due to network/server issues, don't clear the token
      // It might be valid but server is unreachable
      if (e.toString().contains('timeout') || e.toString().contains('connection')) {
        AppLogger.auth('Network issue during validation - keeping token for retry');
        return false;
      }
      // For other errors, clear the token as it might be corrupted
      AppLogger.auth('Clearing potentially corrupted token due to validation error');
      await clearAuth();
      return false;
    }
  }

  // Handle authentication errors consistently
  Future<void> handleAuthError(int statusCode, String endpoint) async {
    if (statusCode == 401 || statusCode == 403) {
      AppLogger.auth('Auth error on $endpoint - clearing token and forcing re-login', isError: true);
      await clearAuth();
      // In a real app, you would also trigger a navigation to login screen
      // For now, we just log the requirement
      AppLogger.auth('User must re-login to continue using the app', isError: true);
    }
  }

  // Check if user is currently authenticated (has valid token)
  bool get isAuthenticated => _authToken != null && _authToken!.isNotEmpty;

  // Get current auth token (masked for logging purposes)
  String get currentTokenMasked => _maskToken(_authToken);


  // Authentication endpoints
  Future<Map<String, dynamic>> registerTourist({
    required String email,
    required String password,
    String? name,
    String? phone,
    String? emergencyContact,
    String? emergencyPhone,
  }) async {
    try {
      // Log the registration attempt with masked password (safe)
      AppLogger.auth('Register attempt: $email | password: ${_maskPassword(password)}');
      
      final requestHeaders = {"Content-Type": "application/json"};
      _logRequest('POST', '/auth/register', headers: requestHeaders, requiresAuth: false);
      
      final response = await _client.post(
        Uri.parse("$baseUrl$apiPrefix/auth/register"),
        headers: requestHeaders,
        body: jsonEncode({
          "email": email,
          "password": password,
          if (name != null) "name": name,
          if (phone != null) "phone": phone,
          if (emergencyContact != null) "emergency_contact": emergencyContact,
          if (emergencyPhone != null) "emergency_phone": emergencyPhone,
        }),
      ).timeout(timeout);

      _logResponse('/auth/register', response.statusCode, body: response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "message": data["message"] ?? "Registration successful",
          "user_id": data["user_id"],
          "email": data["email"],
        };
      }

      final errorData = jsonDecode(response.body);
      throw HttpException("Registration failed: ${errorData['detail'] ?? errorData['message'] ?? 'Unknown error'}");
    } catch (e) {
      AppLogger.auth('User registration failed: $e', isError: true);
      return {
        "success": false,
        "message": e is HttpException ? e.message : "Registration failed. Please check your connection.",
      };
    }
  }

  Future<Map<String, dynamic>> loginTourist({
    required String email,
    required String password,
  }) async {
    try {
      // Log the login attempt with masked password (safe)
      AppLogger.auth('Login attempt: $email | password: ${_maskPassword(password)}');
      
      final requestHeaders = {"Content-Type": "application/json"};
      _logRequest('POST', '/auth/login', headers: requestHeaders, requiresAuth: false);
      
      final response = await _client.post(
        Uri.parse("$baseUrl$apiPrefix/auth/login"),
        headers: requestHeaders,
        body: jsonEncode({
          "email": email,
          "password": password,
        }),
      ).timeout(timeout);

      _logResponse('/auth/login', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data["access_token"];
        
        // Validate token format and length
        if (token == null || token.isEmpty) {
          throw HttpException("Invalid token received from server");
        }
        
        // Log token info for security (masked)
        AppLogger.auth('Login successful - token received: ${_maskToken(token)}');
        
        await _saveAuthToken(token);
        return {
          "success": true,
          "access_token": token,
          "token_type": data["token_type"] ?? "bearer",
          "user_id": data["user_id"],
          "email": data["email"],
          "role": data["role"] ?? "tourist",
        };
      }

      final errorData = jsonDecode(response.body);
      throw HttpException("Login failed: ${errorData['detail'] ?? errorData['message'] ?? 'Invalid credentials'}");
    } catch (e) {
      AppLogger.auth('User login failed: $e', isError: true);
      return {
        "success": false,
        "message": e is HttpException ? e.message : "Login failed. Please check your connection.",
      };
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/auth/me"),
        headers: headers,
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "user": data,
        };
      } else if (response.statusCode == 403) {
        // Token might be corrupted or invalid
        AppLogger.auth('Token validation failed - 403 Forbidden (token may be corrupted)', isError: true);
        
        // Token validation failed with 403
        
        throw HttpException("Authentication failed. Please login again. (Token may be corrupted)");
      } else if (response.statusCode == 401) {
        throw HttpException("Authentication expired. Please login again.");
      }

      throw HttpException("Failed to get user profile: ${response.statusCode}");
    } catch (e) {
      AppLogger.auth('Failed to get current user profile', isError: true);
      return {
        "success": false,
        "message": e is HttpException ? e.message : "Failed to load user profile.",
      };
    }
  }

  // Location tracking endpoints
  Future<Map<String, dynamic>> updateLocation({
    required double lat,
    required double lon,
    double? speed,
    double? altitude,
    double? accuracy,
    DateTime? timestamp,
  }) async {
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      final requestHeaders = await safeHeaders;
      final response = await _client.post(
        Uri.parse("$baseUrl$apiPrefix/location/update"),
        headers: requestHeaders,
        body: jsonEncode({
          "lat": lat,
          "lon": lon,
          if (speed != null) "speed": speed,
          if (altitude != null) "altitude": altitude,
          if (accuracy != null) "accuracy": accuracy,
          if (timestamp != null) "timestamp": timestamp.toIso8601String(),
        }),
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          "success": true,
          "status": data["status"],
          "location_id": data["location_id"],
          "safety_score": data["safety_score"],
          "risk_level": data["risk_level"],
          "lat": data["lat"],
          "lon": data["lon"],
          "timestamp": data["timestamp"],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/location/update');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to update location: ${response.statusCode}");
    } catch (e) {
      AppLogger.location('Location update failed', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow; // Let auth errors bubble up
      }
      return {
        "success": false,
        "message": "Failed to update location. Please check your connection.",
      };
    }
  }

  Future<Map<String, dynamic>> getLocationHistory({
    int limit = 100,
    int? hoursBack,
    int? tripId,
  }) async {
    await _ensureInitialized();
    
    try {
      // Build query parameters
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (hoursBack != null) queryParams['hours_back'] = hoursBack.toString();
      if (tripId != null) queryParams['trip_id'] = tripId.toString();
      
      final uri = Uri.parse("$baseUrl$apiPrefix/location/history")
          .replace(queryParameters: queryParams);
      
      final requestHeaders = await safeHeaders;
      final response = await _client.get(uri, headers: requestHeaders).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          // Handle legacy response format (list of locations)
          return {
            "success": true,
            "locations": data,
            "total": data.length,
          };
        } else {
          // Handle new response format (object with locations array)
          return {
            "success": true,
            "locations": data["locations"] ?? [],
            "total": data["total"] ?? 0,
            "hours_back": data["hours_back"] ?? hoursBack,
          };
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/location/history');
        return {
          "success": false,
          "message": response.statusCode == 401 
            ? "Authentication required. Please login again."
            : "Access denied. Invalid token or permissions.",
          "auth_error": true,
        };
      }

      throw HttpException("Failed to load location history: ${response.statusCode}");
    } catch (e) {
      AppLogger.location('Failed to load location history', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return {
        "success": false,
        "message": "Failed to load location history.",
      };
    }
  }

  // Trip management endpoints
  Future<Map<String, dynamic>> startTrip({
    required String destination,
    String? itinerary,
  }) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('POST', '/trip/start', headers: requestHeaders);
      
      final response = await _client.post(
        Uri.parse("$baseUrl$apiPrefix/trip/start"),
        headers: requestHeaders,
        body: jsonEncode({
          "destination": destination,
          if (itinerary != null) "itinerary": itinerary,
        }),
      ).timeout(timeout);

      _logResponse('/trip/start', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Trip started successfully: ${data["trip_id"]}');
        return {
          "success": true,
          "trip_id": data["trip_id"],
          "destination": data["destination"],
          "status": data["status"],
          "start_date": data["start_date"],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/trip/start');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to start trip: ${response.statusCode}");
    } catch (e) {
      AppLogger.service('Trip start failed: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return {
        "success": false,
        "message": "Failed to start trip.",
      };
    }
  }

  Future<Map<String, dynamic>> endTrip() async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('POST', '/trip/end', headers: requestHeaders);
      
      final response = await _client.post(
        Uri.parse("$baseUrl$apiPrefix/trip/end"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/trip/end', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Trip ended successfully: ${data["trip_id"]}');
        return {
          "success": true,
          "trip_id": data["trip_id"],
          "status": data["status"],
          "end_date": data["end_date"],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/trip/end');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to end trip: ${response.statusCode}");
    } catch (e) {
      AppLogger.service('Trip end failed: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return {
        "success": false,
        "message": "Failed to end trip.",
      };
    }
  }

  Future<Map<String, dynamic>> getTripHistory() async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/trip/history', headers: requestHeaders);
      
      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/trip/history"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/trip/history', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        AppLogger.info('Trip history retrieved successfully (${data.length} trips)');
        return {
          "success": true,
          "trips": data,
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/trip/history');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to load trip history: ${response.statusCode}");
    } catch (e) {
      AppLogger.service('Failed to load trip history: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return {
        "success": false,
        "message": "Failed to load trip history.",
      };
    }
  }

  // Safety and emergency endpoints
  Future<Map<String, dynamic>> getSafetyScore() async {
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/safety/score', headers: requestHeaders);
      
      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/safety/score"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/safety/score', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Safety score retrieved successfully');
        return {
          "success": true,
          "safety_score": data["safety_score"],
          "risk_level": data["risk_level"],
          "last_updated": data["last_updated"],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/safety/score');
        return {
          "success": false,
          "message": response.statusCode == 401 
            ? "Authentication required. Please login again."
            : "Access denied. Invalid token or permissions.",
          "auth_error": true,
        };
      }

      throw HttpException("Failed to get safety score: ${response.statusCode} - ${response.body}");
    } catch (e) {
      AppLogger.error('Safety score request failed', error: e);
      return {
        "success": false,
        "message": "Failed to get safety score: ${e.toString()}",
      };
    }
  }

  /// Get nearby risks for a specific location
  /// Endpoint: GET /location/nearby-risks?radius_km=2.0
  Future<Map<String, dynamic>> getNearbyRisks({
    double? lat,
    double? lon,
    double radiusKm = 2.0,
  }) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      
      // Build query parameters
      final queryParams = <String, String>{
        'radius_km': radiusKm.toString(),
      };
      if (lat != null) queryParams['lat'] = lat.toString();
      if (lon != null) queryParams['lon'] = lon.toString();
      
      final uri = Uri.parse("$baseUrl$apiPrefix/location/nearby-risks")
          .replace(queryParameters: queryParams);
      
      _logRequest('GET', '/location/nearby-risks', headers: requestHeaders);
      
      final response = await _client.get(uri, headers: requestHeaders).timeout(timeout);
      
      _logResponse('/location/nearby-risks', response.statusCode, body: response.body);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Nearby risks retrieved successfully');
        return {
          "success": true,
          ...data,
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/location/nearby-risks');
        return {
          "success": false,
          "message": response.statusCode == 401 
            ? "Authentication required. Please login again."
            : "Access denied. Invalid token or permissions.",
          "auth_error": true,
        };
      }

      throw HttpException("Failed to get nearby risks: ${response.statusCode}");
    } catch (e) {
      AppLogger.error('Nearby risks request failed', error: e);
      return {
        "success": false,
        "message": "Failed to get nearby risks: ${e.toString()}",
      };
    }
  }

  /// Get detailed safety analysis for current location
  /// Endpoint: GET /location/safety-analysis
  Future<Map<String, dynamic>> getSafetyAnalysis() async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/location/safety-analysis', headers: requestHeaders);
      
      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/location/safety-analysis"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/location/safety-analysis', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Safety analysis retrieved successfully');
        return {
          "success": true,
          ...data,
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/location/safety-analysis');
        return {
          "success": false,
          "message": response.statusCode == 401 
            ? "Authentication required. Please login again."
            : "Access denied. Invalid token or permissions.",
          "auth_error": true,
        };
      }

      throw HttpException("Failed to get safety analysis: ${response.statusCode}");
    } catch (e) {
      AppLogger.error('Safety analysis request failed', error: e);
      return {
        "success": false,
        "message": "Failed to get safety analysis: ${e.toString()}",
      };
    }
  }

  Future<Map<String, dynamic>> triggerSOS() async {
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('POST', '/sos/trigger', headers: requestHeaders);

      final response = await _client
          .post(
            Uri.parse("$baseUrl$apiPrefix/sos/trigger"),
            headers: requestHeaders,
          )
          .timeout(timeout);

      _logResponse('/sos/trigger', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.emergency('SOS triggered successfully');
        return {
          "success": true,
          "status": data["status"] ?? "sos_triggered",
          "alert_id": data["alert_id"],
          "notifications_sent": data["notifications_sent"],
          "timestamp": data["timestamp"],
        };
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/sos/trigger');
        final msg = response.statusCode == 401
            ? "Authentication required. Please login again."
            : "Access denied. Invalid token or permissions.";
        return {
          "success": false,
          "message": msg,
          "auth_error": true,
          "status_code": response.statusCode,
        };
      }

      // Try to surface server-provided message if available
      String? serverMsg;
      try {
        final body = jsonDecode(response.body);
        serverMsg = body['detail'] ?? body['message'];
      } catch (_) {}

      throw HttpException(
          "Failed to trigger SOS: ${response.statusCode}${serverMsg != null ? ' - $serverMsg' : ''}");
    } catch (e) {
      AppLogger.emergency('SOS trigger failed: $e', isError: true);
      return {
        "success": false,
        "message": "Failed to send SOS alert. ${e is HttpException ? e.message : 'Please try again.'}",
      };
    }
  }

  // Search functionality
  Future<List<Map<String, dynamic>>> searchLocation(String query) async {
    if (query.isEmpty) return [];
    
    try {
      // Using Nominatim for location search as per specifications
      final encodedQuery = Uri.encodeComponent(query);
      final response = await _client.get(
        Uri.parse("$nominatimSearchUrl?format=json&q=$encodedQuery&limit=10"),
        headers: {"User-Agent": "TouristSafetyApp/1.0"},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => {
          "display_name": item["display_name"],
          "lat": double.parse(item["lat"]),
          "lon": double.parse(item["lon"]),
        }).toList();
      }

      throw HttpException("Search failed: ${response.statusCode}");
    } catch (e) {
      AppLogger.service('Location search failed', isError: true);
      return [];
    }
  }

  // Reverse geocoding to get address from coordinates
  Future<String> reverseGeocode({
    required double lat,
    required double lon,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse("${nominatimSearchUrl.replaceAll('/search', '/reverse')}?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1"),
        headers: {"User-Agent": "TouristSafetyApp/1.0"},
      ).timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Try to build a meaningful address from the response
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          List<String> parts = [];
          
          // Add specific location (building, shop, etc.)
          if (address['building'] != null) parts.add(address['building']);
          if (address['shop'] != null) parts.add(address['shop']);
          if (address['tourism'] != null) parts.add(address['tourism']);
          if (address['amenity'] != null) parts.add(address['amenity']);
          
          // Add road/street
          if (address['road'] != null) parts.add(address['road']);
          
          // Add locality
          if (address['neighbourhood'] != null) {
            parts.add(address['neighbourhood']);
          } else if (address['suburb'] != null) {
            parts.add(address['suburb']);
          }
          
          // Add city
          if (address['city'] != null) {
            parts.add(address['city']);
          } else if (address['town'] != null) {
            parts.add(address['town']);
          } else if (address['village'] != null) {
            parts.add(address['village']);
          }
          
          // Add state
          if (address['state'] != null) parts.add(address['state']);
          
          // Return formatted address
          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
        
        // Fallback to display_name if address parsing fails
        return data['display_name'] ?? '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
      }

      // If request fails, return coordinates
      return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
    } catch (e) {
      AppLogger.service('Reverse geocoding failed: $e', isError: true);
      // Return coordinates as fallback
      return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
    }
  }

  // Geofencing and zone management
  Future<Map<String, dynamic>> checkGeofence({
    required double lat,
    required double lon,
  }) async {
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('POST', '/ai/geofence/check', headers: requestHeaders);
      
      final response = await _client.post(
        Uri.parse("$baseUrl$apiPrefix/ai/geofence/check"),
        headers: requestHeaders,
        body: jsonEncode({
          "lat": lat,
          "lon": lon,
        }),
      ).timeout(timeout);

      _logResponse('/ai/geofence/check', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Geofence check successful: ${data["risk_level"]}');
        return {
          "success": true,
          "inside_restricted": data["inside_restricted"] ?? false,
          "risk_level": data["risk_level"] ?? "safe",
          "zones": data["zones"] ?? [],
          "checked_at": data["checked_at"],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/ai/geofence/check');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to check geofence: ${response.statusCode}");
    } catch (e) {
      AppLogger.location('Geofence check failed: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow; // Let auth errors bubble up
      }
      return {
        "success": false,
        "inside_restricted": false,
        "risk_level": "safe",
        "zones": [],
      };
    }
  }

  Future<List<Map<String, dynamic>>> getSafetyZones() async {
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/heatmap/zones/public', headers: requestHeaders);
      
      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/heatmap/zones/public"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/heatmap/zones/public', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> zones = data['zones'] ?? [];
        AppLogger.info('Safety zones retrieved successfully (${zones.length} zones)');
        return zones.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/heatmap/zones/public');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to load safety zones: ${response.statusCode} - ${response.body}");
    } catch (e) {
      AppLogger.location('Failed to load safety zones', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow; // Let auth errors bubble up
      }
      return [];
    }
  }

  // Heatmap and analytics data
  Future<List<GeospatialHeatPoint>> getPanicAlertHeatData({
    int? daysPast = 30,
    double? minLat,
    double? maxLat, 
    double? minLng,
    double? maxLng,
    String? excludeTouristId, // Exclude alerts from this tourist
  }) async {
    try {
      final requestHeaders = await safeHeaders;
      
      // Use the correct heatmap/alerts endpoint
      final endpoint = '/heatmap/alerts';
      
      // Build query parameters
      final queryParams = <String, String>{
        'hours_back': ((daysPast ?? 30) * 24).toString(), // Convert days to hours
        'severity': 'high', // Only high-severity alerts (includes SOS)
      };
      
      // Add exclude parameter if provided (to hide self-created alerts from heatmap)
      if (excludeTouristId != null && excludeTouristId.isNotEmpty) {
        queryParams['exclude_tourist_id'] = excludeTouristId;
        AppLogger.info('🚫 Excluding alerts from tourist: $excludeTouristId (heatmap)');
      }
      
      // Add bounding box if provided
      if (minLat != null) queryParams['bounds_south'] = minLat.toStringAsFixed(6);
      if (maxLat != null) queryParams['bounds_north'] = maxLat.toStringAsFixed(6);
      if (minLng != null) queryParams['bounds_west'] = minLng.toStringAsFixed(6);
      if (maxLng != null) queryParams['bounds_east'] = maxLng.toStringAsFixed(6);
      
      final uri = Uri.parse('$baseUrl$apiPrefix$endpoint').replace(
        queryParameters: queryParams,
      );
      
      _logRequest('GET', endpoint, headers: requestHeaders);
      
      final response = await _client.get(
        uri,
        headers: requestHeaders,
      ).timeout(timeout);
      
      _logResponse(endpoint, response.statusCode);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> alerts = responseData['alerts'] ?? [];
        
        AppLogger.info('📊 Received ${alerts.length} alerts for heatmap');
        
        // Filter for SOS/panic alerts and exclude self-created ones
        final panicAlerts = alerts.where((alert) {
          // Filter by type
          if (alert["type"]?.toLowerCase() != "sos") return false;
          
          // Filter out self-created alerts (client-side fallback)
          if (excludeTouristId != null && excludeTouristId.isNotEmpty) {
            final alertTouristId = alert["tourist_id"]?.toString();
            if (alertTouristId == excludeTouristId) {
              AppLogger.info('🚫 Filtered out self-created alert from heatmap');
              return false;
            }
          }
          
          return true;
        }).toList();
        
        AppLogger.info('🚨 Filtered to ${panicAlerts.length} SOS alerts for heatmap');

        return _aggregatePanicAlertsFromBackend(panicAlerts);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Tourist users don't have access to alert data - this is expected
        AppLogger.auth('Alert data access denied (role: tourist) - returning empty heatmap', isError: false);
        return []; // Return empty list gracefully
      }

      AppLogger.api('Panic alert heatmap request failed: ${response.statusCode}', isError: true);
      return [];
    } catch (e) {
      AppLogger.api('Panic alert heat data request failed', isError: true);
      return [];
    }
  }

  /// Aggregate panic alerts from backend database into heat points
  List<GeospatialHeatPoint> _aggregatePanicAlertsFromBackend(List<dynamic> data) {
    final Map<String, List<Map<String, dynamic>>> locationGroups = {};
    
    // Group alerts by approximate location (100m grid)
    for (final item in data) {
      final location = item["location"];
      final lat = (location["lat"] as num).toDouble();
      final lng = (location["lon"] as num).toDouble();
      
      // Create location grid key (approx 100m precision)
      final gridKey = "${(lat * 1000).round()},${(lng * 1000).round()}";
      locationGroups[gridKey] ??= [];
      locationGroups[gridKey]!.add({
        'latitude': lat,
        'longitude': lng,
        'timestamp': item["created_at"],
        'tourist_id': item["tourist_id"],
        'description': item["description"],
      });
    }

    return locationGroups.entries.map((entry) {
      final alerts = entry.value;
      final firstAlert = alerts.first;
      
      // Calculate average position
      final avgLat = alerts.map((a) => a["latitude"] as double).reduce((a, b) => a + b) / alerts.length;
      final avgLng = alerts.map((a) => a["longitude"] as double).reduce((a, b) => a + b) / alerts.length;
      
      // Calculate intensity based on alert count and recency
      final alertCount = alerts.length;
      final recentCount = alerts.where((alert) {
        final timestamp = DateTime.tryParse(alert["timestamp"] ?? "");
        return timestamp?.isAfter(DateTime.now().subtract(const Duration(days: 7))) ?? false;
      }).length;
      
      // Intensity formula: base on count + recent activity boost
      final intensity = ((alertCount / 10.0) + (recentCount / 5.0)).clamp(0.1, 1.0);
      
      return GeospatialHeatPoint.fromPanicAlert(
        latitude: avgLat,
        longitude: avgLng,
        intensity: intensity,
        alertCount: alertCount,
        description: alertCount == 1 
            ? "1 emergency alert"
            : "$alertCount emergency alerts",
        timestamp: DateTime.tryParse(firstAlert["timestamp"] ?? "") ?? DateTime.now(),
      );
    }).toList();
  }

  /// Get recent panic alerts near a location (privacy-protected, aggregated data only)
  /// Returns panic alerts within the specified radius, aggregated to protect individual privacy
  Future<List<GeospatialHeatPoint>> getRecentPanicAlerts({
    required double centerLat,
    required double centerLon,
    required double radiusKm,
    int minutesPast = 10,
  }) async {
    try {
      final requestHeaders = await safeHeaders;
      
      // Calculate bounding box for the radius
      const double kmPerDegree = 111.0; // Approximate km per degree of latitude
      final latDelta = radiusKm / kmPerDegree;
      final lonDelta = radiusKm / (kmPerDegree * math.cos(centerLat * math.pi / 180));
      
      final boundsNorth = centerLat + latDelta;
      final boundsSouth = centerLat - latDelta;
      final boundsEast = centerLon + lonDelta;
      final boundsWest = centerLon - lonDelta;
      
      // Convert minutes to hours (API expects hours_back parameter)
      final hoursBack = (minutesPast / 60.0).ceil();
      
      // Use the correct heatmap/alerts endpoint with bounding box
      final endpoint = '/heatmap/alerts';
      final uri = Uri.parse('$baseUrl$apiPrefix$endpoint').replace(
        queryParameters: {
          'hours_back': hoursBack.toString(),
          'severity': 'high', // Only get high-severity alerts (includes SOS)
          'bounds_north': boundsNorth.toStringAsFixed(6),
          'bounds_south': boundsSouth.toStringAsFixed(6),
          'bounds_east': boundsEast.toStringAsFixed(6),
          'bounds_west': boundsWest.toStringAsFixed(6),
        },
      );
      
      _logRequest('GET', endpoint, headers: requestHeaders);
      
      final response = await _client.get(
        uri,
        headers: requestHeaders,
      ).timeout(timeout);
      
      _logResponse(endpoint, response.statusCode);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> alerts = responseData['alerts'] ?? [];
        
        AppLogger.info('📊 Received ${alerts.length} alerts from heatmap API');
        
        // Filter for SOS alerts within the exact radius and time window
        final recentPanicAlerts = alerts.where((alert) {
          // Check if it's an SOS alert
          if (alert["type"]?.toLowerCase() != "sos") return false;
          
          // Check timestamp (within specified minutes)
          final timestamp = DateTime.tryParse(alert["created_at"] ?? "");
          if (timestamp == null) return false;
          
          final minutesAgo = DateTime.now().difference(timestamp).inMinutes;
          if (minutesAgo > minutesPast) return false;
          
          // Check location exists
          final location = alert["location"];
          if (location == null) return false;
          
          final lat = location["lat"]?.toDouble();
          final lon = location["lon"]?.toDouble();
          if (lat == null || lon == null) return false;
          
          // Calculate actual distance to verify it's within radius
          final distance = _calculateDistance(centerLat, centerLon, lat, lon);
          return distance <= radiusKm;
        }).toList();
        
        AppLogger.info('🚨 Filtered to ${recentPanicAlerts.length} SOS alerts within ${radiusKm}km and ${minutesPast}min');
        
        // Convert to GeospatialHeatPoint format
        return _convertHeatmapAlertsToHeatPoints(recentPanicAlerts);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        AppLogger.auth('Alert data access denied - returning empty list', isError: false);
        return [];
      }
      
      AppLogger.api('Recent panic alerts request failed: ${response.statusCode}', isError: true);
      return [];
    } catch (e) {
      AppLogger.error('Recent panic alerts request failed: $e');
      return [];
    }
  }

  /// Convert heatmap alerts API format to GeospatialHeatPoint
  List<GeospatialHeatPoint> _convertHeatmapAlertsToHeatPoints(List<dynamic> alerts) {
    return alerts.map<GeospatialHeatPoint>((alert) {
      final location = alert["location"];
      final lat = (location["lat"] as num).toDouble();
      final lon = (location["lon"] as num).toDouble();
      
      // Use severity and weight to calculate intensity
      final severity = alert["severity"]?.toString() ?? "medium";
      final weight = (alert["weight"] as num?)?.toDouble() ?? 0.5;
      
      // Map severity to intensity (0.0 - 1.0)
      double intensity;
      switch (severity.toLowerCase()) {
        case 'critical':
          intensity = 1.0;
          break;
        case 'high':
          intensity = 0.8;
          break;
        case 'medium':
          intensity = 0.6;
          break;
        case 'low':
          intensity = 0.4;
          break;
        default:
          intensity = weight; // Use weight if severity unknown
      }
      
      final description = alert["description"]?.toString() ?? 
                         alert["title"]?.toString() ?? 
                         "Emergency alert";
      
      final timestamp = DateTime.tryParse(alert["created_at"] ?? "") ?? DateTime.now();
      
      return GeospatialHeatPoint.fromPanicAlert(
        latitude: lat,
        longitude: lon,
        intensity: intensity,
        alertCount: 1, // Each heatmap alert represents aggregated data
        description: description,
        timestamp: timestamp,
      );
    }).toList();
  }

  /// Get active panic alerts from public endpoint (No authentication required)
  /// This is a PUBLIC endpoint that provides anonymized emergency alerts for community safety
  Future<List<Map<String, dynamic>>> getPublicPanicAlerts({
    int limit = 50,
    int hoursBack = 24,
    String? excludeTouristId, // Exclude alerts from this tourist
  }) async {
    try {
      // PUBLIC ENDPOINT - No authentication required
      // Correct endpoint: /api/public/panic-alerts (not /notify/public/panic-alerts)
      final endpoint = '/public/panic-alerts';
      
      final queryParams = {
        'limit': limit.toString(),
        'hours_back': hoursBack.toString(),
      };
      
      // Add exclude parameter if provided (to hide self-created alerts)
      if (excludeTouristId != null && excludeTouristId.isNotEmpty) {
        queryParams['exclude_tourist_id'] = excludeTouristId;
      }
      
      final uri = Uri.parse('$baseUrl$apiPrefix$endpoint').replace(
        queryParameters: queryParams,
      );
      
      AppLogger.info('📡 Fetching public panic alerts (no auth required)');
      AppLogger.info('📡 Request URL: $uri');
      if (excludeTouristId != null) {
        AppLogger.info('🚫 Excluding alerts from tourist: $excludeTouristId');
      }
      
      // Use client.get WITHOUT authentication headers
      final response = await _client.get(uri).timeout(timeout);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> alerts = responseData['alerts'] ?? [];
        final int totalAlerts = responseData['total_alerts'] ?? 0;
        final int activeCount = responseData['active_count'] ?? 0;
        
        AppLogger.info('🚨 Public panic alerts: $activeCount active / $totalAlerts total');
        
        // Convert to map format for easier use
        return alerts.map<Map<String, dynamic>>((alert) {
          // Handle null location gracefully
          Map<String, dynamic>? locationData;
          if (alert['location'] != null) {
            locationData = {
              'lat': alert['location']['lat'],
              'lon': alert['location']['lon'],
              'timestamp': alert['location']['timestamp'],
            };
          }
          
          return {
            'alert_id': alert['alert_id'],
            'type': alert['type'],
            'severity': alert['severity'],
            'title': alert['title'],
            'description': alert['description'],
            'location': locationData,
            'timestamp': alert['timestamp'],
            'time_ago': alert['time_ago'],
            'status': alert['status'], // 'active' (<1hr) or 'older' (1-24hr)
            'resolved': alert['resolved'] ?? false,
            'resolved_at': alert['resolved_at'],
            'tourist_id': alert['tourist_id'], // May be null if backend doesn't provide it
            'user_id': alert['user_id'], // Alternative field name
          };
        }).toList();
      }
      
      AppLogger.api('Public panic alerts request failed: ${response.statusCode}', isError: true);
      return [];
    } catch (e) {
      AppLogger.error('Public panic alerts request failed: $e');
      return [];
    }
  }

  /// Convert public panic alerts to GeospatialHeatPoint format for map display
  List<GeospatialHeatPoint> convertPublicAlertsToHeatPoints(List<Map<String, dynamic>> alerts) {
    return alerts.map<GeospatialHeatPoint>((alert) {
      final location = alert['location'] as Map<String, dynamic>;
      final lat = (location['lat'] as num).toDouble();
      final lon = (location['lon'] as num).toDouble();
      
      // Map severity to intensity
      final severity = alert['severity']?.toString() ?? 'medium';
      final status = alert['status']?.toString() ?? 'older';
      
      double intensity;
      if (status == 'active') {
        // Active alerts (<1 hour) are high priority
        intensity = severity == 'critical' ? 1.0 : 0.9;
      } else {
        // Older alerts (1-24 hours) have lower intensity
        intensity = severity == 'critical' ? 0.7 : 0.5;
      }
      
      final title = alert['title']?.toString() ?? 'Emergency Alert';
      final timeAgo = alert['time_ago']?.toString() ?? 'unknown';
      final description = '$title • $timeAgo ago';
      
      final timestamp = DateTime.tryParse(alert['timestamp'] ?? '') ?? DateTime.now();
      
      return GeospatialHeatPoint.fromPanicAlert(
        latitude: lat,
        longitude: lon,
        intensity: intensity,
        alertCount: 1,
        description: description,
        timestamp: timestamp,
      );
    }).toList();
  }

  /// Get nearby unresolved alerts and panic alerts
  /// This shows active incidents in the area that haven't been resolved
  Future<List<Alert>> getNearbyUnresolvedAlerts({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    try {
      final requestHeaders = await safeHeaders;
      
      final queryParams = <String, String>{
        'lat': latitude.toStringAsFixed(6),
        'lon': longitude.toStringAsFixed(6),
        'radius_km': radiusKm.toString(),
        'status': 'unresolved', // Only show unresolved alerts
        'include_panic': 'true', // Include panic/SOS alerts
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(), // Force fresh data
      };
      
      final uri = Uri.parse('$baseUrl$apiPrefix/alerts/nearby').replace(
        queryParameters: queryParams,
      );
      
      AppLogger.info('🚨 API Request: GET /alerts/nearby for ${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)} (${radiusKm}km)');
      _logRequest('GET', '/alerts/nearby', headers: requestHeaders);
      
      final response = await _client.get(
        uri,
        headers: requestHeaders,
      ).timeout(timeout);
      
      _logResponse('/alerts/nearby', response.statusCode);
      AppLogger.info('🚨 API Response: ${response.statusCode} for nearby alerts');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> alertsData = responseData['alerts'] ?? [];
        
        AppLogger.info('🚨 Raw API returned ${alertsData.length} alerts');
        
        final alerts = alertsData.map((data) {
          try {
            final alert = Alert.fromJson(data);
            AppLogger.info('🚨 Parsed alert: ${alert.title} at ${alert.latitude}, ${alert.longitude}');
            return alert;
          } catch (e) {
            AppLogger.warning('Failed to parse alert: $e');
            AppLogger.warning('Alert data: $data');
            return null;
          }
        }).where((alert) => alert != null).cast<Alert>().toList();
        
        AppLogger.info('🚨 Successfully parsed ${alerts.length} nearby unresolved alerts');
        return alerts;
      } else if (response.statusCode == 404) {
        AppLogger.info('ℹ️ No nearby alerts found (404)');
        return []; // Return empty list when no alerts found
      } else {
        AppLogger.warning('🚨 API failed with status ${response.statusCode}');
        return []; // Return empty list on API failure
      }
    } catch (e) {
      AppLogger.error('Failed to fetch nearby alerts', error: e);
      AppLogger.info('🚨 Returning empty list due to API error');
      return []; // Return empty list instead of mock data
    }
  }

  /// Get all active alerts for display on home screen
  Future<List<Alert>> getActiveAlerts({
    double? latitude,
    double? longitude,
    double radiusKm = 10.0,
  }) async {
    try {
      final requestHeaders = await safeHeaders;
      
      final queryParams = <String, String>{
        'status': 'active', // Active (unresolved) alerts
        'limit': '50', // Limit to prevent overwhelming UI
      };
      
      // Add location filtering if provided
      if (latitude != null && longitude != null) {
        queryParams['lat'] = latitude.toStringAsFixed(6);
        queryParams['lon'] = longitude.toStringAsFixed(6);
        queryParams['radius_km'] = radiusKm.toString();
      }
      
      final uri = Uri.parse('$baseUrl$apiPrefix/alerts/active').replace(
        queryParameters: queryParams,
      );
      
      _logRequest('GET', '/alerts/active', headers: requestHeaders);
      
      final response = await _client.get(
        uri,
        headers: requestHeaders,
      ).timeout(timeout);
      
      _logResponse('/alerts/active', response.statusCode);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> alertsData = responseData['alerts'] ?? [];
        
        final alerts = alertsData.map((data) {
          try {
            return Alert.fromJson(data);
          } catch (e) {
            AppLogger.warning('Failed to parse active alert: $e');
            return null;
          }
        }).where((alert) => alert != null).cast<Alert>().toList();
        
        AppLogger.info('🏠 Found ${alerts.length} active alerts for home screen');
        return alerts;
      } else {
        throw HttpException('Failed to get active alerts: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.error('Failed to fetch active alerts', error: e);
      // Return empty list instead of mock data
      return [];
    }
  }

  // Mock alert methods removed - now using only real backend data

  /// Calculate distance between two points in kilometers (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0; // km
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a));
    
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  // Additional missing methods for compatibility
  Future<List<RestrictedZone>> getRestrictedZones() async {
    await _ensureInitialized(); // Ensure auth is initialized before API calls
    
    try {
      // Use the heatmap zones endpoint which provides better data structure
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/heatmap/zones/public', headers: requestHeaders);
      
      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/heatmap/zones/public"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/heatmap/zones/public', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> zones = data['zones'] ?? [];
        
        // Filter out zones with invalid/missing coordinates instead of crashing
        final List<RestrictedZone> restrictedZones = [];
        int skippedCount = 0;
        
        for (var item in zones) {
          try {
            restrictedZones.add(RestrictedZone.fromJson(item));
          } catch (e) {
            skippedCount++;
            AppLogger.warning('Skipped invalid zone: ${item['name'] ?? 'Unknown'} - Missing coordinates data');
          }
        }
        
        if (skippedCount > 0) {
          AppLogger.warning('⚠️ Skipped $skippedCount zones with invalid/missing coordinates');
        }
        
        AppLogger.info('Loaded ${restrictedZones.length} valid restricted zones from heatmap API');
        return restrictedZones;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/heatmap/zones/public');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to load restricted zones: ${response.statusCode} - ${response.body}");
    } catch (e) {
      AppLogger.location('Failed to load restricted zones from heatmap API', isError: true);
      
      // Return empty list instead of crashing the app
      AppLogger.location('Returning empty restricted zones list for graceful degradation', isError: true);
      return [];
    }
  }

  Future<List<Alert>> getAlerts([int? touristId]) async {
    // This method returns empty list for tourists as alerts are managed differently
    // Individual alert notifications are handled through push notifications
    return [];
  }

  Future<bool> markAlertAsRead(String alertId) async {
    // This method is not available for tourists in the new API
    return false;
  }

  Future<bool> deleteAlert(String alertId) async {
    // This method is not available for tourists in the new API
    return false;
  }

  Future<Map<String, dynamic>> sendPanicAlert({
    required int touristId,
    required double latitude,
    required double longitude,
  }) async {
    // Use the new SOS endpoint instead
    return await triggerSOS();
  }

  // Zone Management Endpoints
  /// Get all zones (accessible to all authenticated users)
  /// Endpoint: GET /zones/list
  Future<List<Map<String, dynamic>>> getZonesList() async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/zones/list', headers: requestHeaders);
      
      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/zones/list"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/zones/list', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        AppLogger.info('Zones list retrieved successfully (${data.length} zones)');
        return data.cast<Map<String, dynamic>>();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/zones/list');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to load zones list: ${response.statusCode}");
    } catch (e) {
      AppLogger.location('Failed to load zones list: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return [];
    }
  }

  // Notification Endpoints
  /// Get notification history
  /// Endpoint: GET /notify/history
  Future<Map<String, dynamic>> getNotificationHistory({int hours = 24}) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/notify/history', headers: requestHeaders);
      
      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/notify/history?hours=$hours"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/notify/history', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Notification history retrieved successfully');
        return {
          "success": true,
          "notifications": data["notifications"] ?? [],
          "period_hours": data["period_hours"] ?? hours,
          "total": data["total"] ?? 0,
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/notify/history');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to load notification history: ${response.statusCode}");
    } catch (e) {
      AppLogger.service('Failed to load notification history: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return {
        "success": false,
        "notifications": [],
        "period_hours": hours,
        "total": 0,
      };
    }
  }

  /// Get notification settings for current user
  /// Endpoint: GET /notify/settings
  Future<Map<String, dynamic>> getNotificationSettings() async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/notify/settings', headers: requestHeaders);
      
      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/notify/settings"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/notify/settings', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Notification settings retrieved successfully');
        return {
          "success": true,
          "settings": data,
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/notify/settings');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to load notification settings: ${response.statusCode}");
    } catch (e) {
      AppLogger.service('Failed to load notification settings: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return {
        "success": false,
        "settings": null,
      };
    }
  }

  /// Update notification settings
  /// Endpoint: PUT /notify/settings
  Future<Map<String, dynamic>> updateNotificationSettings({
    bool? pushEnabled,
    bool? smsEnabled,
    bool? emailEnabled,
    Map<String, bool>? notificationTypes,
  }) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('PUT', '/notify/settings', headers: requestHeaders);
      
      final response = await _client.put(
        Uri.parse("$baseUrl$apiPrefix/notify/settings"),
        headers: requestHeaders,
        body: jsonEncode({
          if (pushEnabled != null) "push_enabled": pushEnabled,
          if (smsEnabled != null) "sms_enabled": smsEnabled,
          if (emailEnabled != null) "email_enabled": emailEnabled,
          if (notificationTypes != null) "notification_types": notificationTypes,
        }),
      ).timeout(timeout);

      _logResponse('/notify/settings', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Notification settings updated successfully');
        return {
          "success": true,
          "updated_settings": data["updated_settings"],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/notify/settings');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to update notification settings: ${response.statusCode}");
    } catch (e) {
      AppLogger.service('Failed to update notification settings: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return {
        "success": false,
        "message": "Failed to update notification settings.",
      };
    }
  }

  // ========== New Tourist API Endpoints ==========

  /// Generate E-FIR for tourist-reported incident
  /// Endpoint: POST /api/efir/generate
  Future<Map<String, dynamic>> generateTouristEFir({
    required String incidentDescription,
    required String incidentType,
    required String location,
    required DateTime timestamp,
    List<String>? witnesses,
    String? additionalDetails,
  }) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('POST', '/efir/generate', headers: requestHeaders);
      
      final response = await _client.post(
        Uri.parse("$baseUrl$apiPrefix/efir/generate"),
        headers: requestHeaders,
        body: jsonEncode({
          "incident_description": incidentDescription,
          "incident_type": incidentType,
          "location": location,
          "timestamp": timestamp.toIso8601String(),
          if (witnesses != null) "witnesses": witnesses,
          if (additionalDetails != null) "additional_details": additionalDetails,
        }),
      ).timeout(timeout);

      _logResponse('/efir/generate', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Tourist E-FIR generated successfully: ${data["fir_number"]}');
        return {
          "success": true,
          "fir_number": data["fir_number"],
          "blockchain_tx_id": data["blockchain_tx_id"],
          "timestamp": data["timestamp"],
          "verification_url": data["verification_url"],
          "status": data["status"],
          "reference_number": data["reference_number"],
          "message": data["message"],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/efir/generate');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      final errorData = jsonDecode(response.body);
      throw HttpException("E-FIR generation failed: ${errorData['detail'] ?? 'Unknown error'}");
    } catch (e) {
      AppLogger.service('Tourist E-FIR generation failed: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return {
        "success": false,
        "message": "Failed to generate E-FIR: ${e.toString()}",
      };
    }
  }

  /// Debug endpoint to check user role and permissions
  /// Endpoint: GET /api/debug/role
  Future<Map<String, dynamic>> debugRole() async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      _logRequest('GET', '/debug/role', headers: requestHeaders);
      
      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/debug/role"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/debug/role', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Role debug successful: ${data["role"]}');
        return {
          "success": true,
          "user_id": data["user_id"],
          "email": data["email"],
          "role": data["role"],
          "is_tourist": data["is_tourist"],
          "is_authority": data["is_authority"],
          "is_admin": data["is_admin"],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/debug/role');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Role debug failed: ${response.statusCode}");
    } catch (e) {
      AppLogger.service('Role debug failed: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return {
        "success": false,
        "message": "Failed to debug role: ${e.toString()}",
      };
    }
  }

  /// Get nearby zones within specified radius
  /// Endpoint: GET /api/zones/nearby
  Future<Map<String, dynamic>> getNearbyZones({
    required double lat,
    required double lon,
    int radius = 5000,
  }) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      final uri = Uri.parse("$baseUrl$apiPrefix/zones/nearby")
          .replace(queryParameters: {
            'lat': lat.toString(),
            'lon': lon.toString(),
            'radius': radius.toString(),
          });
      
      _logRequest('GET', '/zones/nearby', headers: requestHeaders);
      
      final response = await _client.get(uri, headers: requestHeaders).timeout(timeout);

      _logResponse('/zones/nearby', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Nearby zones retrieved successfully (${data["total"]} zones)');
        return {
          "success": true,
          "nearby_zones": data["nearby_zones"] ?? [],
          "center": data["center"],
          "radius_meters": data["radius_meters"],
          "total": data["total"],
          "generated_at": data["generated_at"],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/zones/nearby');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to get nearby zones: ${response.statusCode}");
    } catch (e) {
      AppLogger.location('Failed to get nearby zones: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return {
        "success": false,
        "nearby_zones": [],
        "total": 0,
      };
    }
  }

  /// Get public zone heatmap data
  /// Endpoint: GET /api/heatmap/zones/public
  Future<Map<String, dynamic>> getPublicZoneHeatmap({
    double? boundsNorth,
    double? boundsSouth,
    double? boundsEast,
    double? boundsWest,
    String? zoneType,
  }) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      final queryParams = <String, String>{};
      if (boundsNorth != null) queryParams['bounds_north'] = boundsNorth.toString();
      if (boundsSouth != null) queryParams['bounds_south'] = boundsSouth.toString();
      if (boundsEast != null) queryParams['bounds_east'] = boundsEast.toString();
      if (boundsWest != null) queryParams['bounds_west'] = boundsWest.toString();
      if (zoneType != null) queryParams['zone_type'] = zoneType;
      
      final uri = Uri.parse("$baseUrl$apiPrefix/heatmap/zones/public")
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      
      _logRequest('GET', '/heatmap/zones/public', headers: requestHeaders);
      
      final response = await _client.get(uri, headers: requestHeaders).timeout(timeout);

      _logResponse('/heatmap/zones/public', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('Public zone heatmap retrieved successfully');
        return {
          "success": true,
          "zones": data["zones"] ?? [],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/heatmap/zones/public');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. Invalid token or permissions.");
      }

      throw HttpException("Failed to get public zone heatmap: ${response.statusCode}");
    } catch (e) {
      AppLogger.location('Failed to get public zone heatmap: $e', isError: true);
      if (e is HttpException && (e.message.contains('Authentication required') || e.message.contains('Access denied'))) {
        rethrow;
      }
      return {
        "success": false,
        "zones": [],
      };
    }
  }

  /// Generate E-FIR (Electronic First Information Report)
  Future<Map<String, dynamic>> generateEFIR({
    required String incidentDescription,
    required String incidentType,
    String? location,
    DateTime? timestamp,
    List<String>? witnesses,
    String? additionalDetails,
  }) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      final requestBody = {
        'incident_description': incidentDescription,
        'incident_type': incidentType,
        if (location != null) 'location': location,
        'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
        'witnesses': witnesses ?? [],
        if (additionalDetails != null) 'additional_details': additionalDetails,
      };

      _logRequest('POST', '/tourist/efir/generate', headers: requestHeaders);
      AppLogger.emergency('📋 Generating E-FIR for incident type: $incidentType');

      final response = await _client.post(
        Uri.parse("$baseUrl$apiPrefix/tourist/efir/generate"),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
      ).timeout(timeout);

      _logResponse('/tourist/efir/generate', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.emergency('✅ E-FIR generated successfully: ${data['fir_number']}');
        AppLogger.info('Blockchain TX ID: ${data['blockchain_tx_id']}');
        AppLogger.info('Reference Number: ${data['reference_number']}');
        
        return {
          "success": true,
          "message": data['message'] ?? 'E-FIR generated successfully',
          "fir_number": data['fir_number'],
          "blockchain_tx_id": data['blockchain_tx_id'],
          "reference_number": data['reference_number'],
          "timestamp": data['timestamp'],
          "verification_url": data['verification_url'],
          "status": data['status'],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/tourist/efir/generate');
        throw HttpException(response.statusCode == 401 
          ? "Authentication required. Please login again."
          : "Access denied. You don't have permission to generate E-FIR.");
      } else if (response.statusCode == 404) {
        throw HttpException("Tourist profile not found.");
      }

      final error = jsonDecode(response.body);
      throw HttpException(error['detail'] ?? 'Failed to generate E-FIR');
    } catch (e) {
      AppLogger.emergency('Failed to generate E-FIR: $e', isError: true);
      if (e is HttpException) rethrow;
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  /// Get E-FIR history for the tourist
  Future<Map<String, dynamic>> getEFIRHistory() async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      
      _logRequest('GET', '/tourist/efir/history', headers: requestHeaders);

      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/tourist/efir/history"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/tourist/efir/history', response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('E-FIR history retrieved successfully');
        
        return {
          "success": true,
          "efirs": data['efirs'] ?? [],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/tourist/efir/history');
        throw HttpException("Authentication failed. Please login again.");
      }

      AppLogger.warning('E-FIR history endpoint returned ${response.statusCode}');
      return {
        "success": false,
        "efirs": [],
        "message": "Failed to load E-FIR history",
      };
    } catch (e) {
      AppLogger.error('Failed to get E-FIR history: $e');
      return {
        "success": false,
        "efirs": [],
        "message": e.toString(),
      };
    }
  }

  /// Verify E-FIR on blockchain
  Future<Map<String, dynamic>> verifyEFIRBlockchain(String blockchainTxId) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      
      _logRequest('GET', '/blockchain/verify/$blockchainTxId', headers: requestHeaders);

      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/blockchain/verify/$blockchainTxId"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/blockchain/verify/$blockchainTxId', response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.info('E-FIR blockchain verification successful');
        
        return {
          "success": true,
          "valid": data['valid'] ?? false,
          "tx_id": data['tx_id'],
          "status": data['status'],
          "chain_id": data['chain_id'],
          "verified_at": data['verified_at'],
        };
      }

      return {
        "success": false,
        "valid": false,
        "message": "Failed to verify E-FIR",
      };
    } catch (e) {
      AppLogger.error('Failed to verify E-FIR on blockchain: $e');
      return {
        "success": false,
        "valid": false,
        "message": e.toString(),
      };
    }
  }

  // ============================================================================
  // BROADCAST & NOTIFICATION ENDPOINTS
  // ============================================================================

  /// Register device for push notifications
  Future<Map<String, dynamic>> registerDevice({
    required String deviceToken,
    required String deviceType,
    String? deviceName,
    String? appVersion,
  }) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      final requestBody = {
        'device_token': deviceToken,
        'device_type': deviceType,
        if (deviceName != null) 'device_name': deviceName,
        if (appVersion != null) 'app_version': appVersion,
      };

      _logRequest('POST', '/device/register', headers: requestHeaders);
      AppLogger.service('📱 Registering device for push notifications...');

      final response = await _client.post(
        Uri.parse("$baseUrl$apiPrefix/device/register"),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
      ).timeout(timeout);

      _logResponse('/device/register', response.statusCode, body: response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Log full response for debugging
        AppLogger.service('📦 Device registration response: $data');
        
        // Extract device_id with null safety
        final deviceId = data['device_id'] ?? data['id'] ?? data['deviceId'];
        if (deviceId != null) {
          AppLogger.service('✅ Device registered successfully: $deviceId');
        } else {
          AppLogger.service('✅ Device registered (no device_id in response)');
        }
        
        return {
          "success": true,
          "device_id": deviceId,
          "message": data['message'] ?? 'Device registered for push notifications',
          "raw_response": data, // Include full response for debugging
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/device/register');
        throw HttpException("Authentication failed. Please login again.");
      }

      final error = jsonDecode(response.body);
      throw HttpException(error['detail'] ?? 'Failed to register device');
    } catch (e) {
      AppLogger.service('Failed to register device: $e', isError: true);
      if (e is HttpException) rethrow;
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  /// Get active broadcasts affecting current location
  Future<Map<String, dynamic>> getActiveBroadcasts({
    double? lat,
    double? lon,
  }) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      
      final queryParams = <String, String>{};
      if (lat != null) queryParams['lat'] = lat.toString();
      if (lon != null) queryParams['lon'] = lon.toString();
      
      final uri = Uri.parse("$baseUrl$apiPrefix/broadcasts/active")
          .replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      
      _logRequest('GET', '/broadcasts/active', headers: requestHeaders);

      final response = await _client.get(uri, headers: requestHeaders).timeout(timeout);

      _logResponse('/broadcasts/active', response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.service('✅ Active broadcasts retrieved: ${data['count']} broadcasts');
        
        return {
          "success": true,
          "active_broadcasts": data['active_broadcasts'] ?? [],
          "count": data['count'] ?? 0,
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/broadcasts/active');
        throw HttpException("Authentication failed. Please login again.");
      }

      AppLogger.warning('Get active broadcasts returned ${response.statusCode}');
      return {
        "success": false,
        "active_broadcasts": [],
        "count": 0,
      };
    } catch (e) {
      AppLogger.service('Failed to get active broadcasts: $e', isError: true);
      if (e is HttpException && e.message.contains('Authentication failed')) rethrow;
      return {
        "success": false,
        "active_broadcasts": [],
        "count": 0,
      };
    }
  }

  /// Acknowledge a broadcast
  Future<Map<String, dynamic>> acknowledgeBroadcast({
    required String broadcastId,
    required String status, // 'safe', 'affected', 'need_help'
    double? lat,
    double? lon,
    String? notes,
  }) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      final requestBody = {
        'status': status,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      _logRequest('POST', '/broadcasts/$broadcastId/acknowledge', headers: requestHeaders);
      AppLogger.service('📢 Acknowledging broadcast: $broadcastId with status: $status');

      final response = await _client.post(
        Uri.parse("$baseUrl$apiPrefix/broadcasts/$broadcastId/acknowledge"),
        headers: requestHeaders,
        body: jsonEncode(requestBody),
      ).timeout(timeout);

      _logResponse('/broadcasts/$broadcastId/acknowledge', response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.service('✅ Broadcast acknowledged successfully');
        
        return {
          "success": true,
          "status": data['status'],
          "broadcast_id": data['broadcast_id'],
          "acknowledgment_status": data['acknowledgment_status'],
          "timestamp": data['timestamp'],
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/broadcasts/$broadcastId/acknowledge');
        throw HttpException("Authentication failed. Please login again.");
      } else if (response.statusCode == 404) {
        throw HttpException("Broadcast not found.");
      }

      final error = jsonDecode(response.body);
      throw HttpException(error['detail'] ?? 'Failed to acknowledge broadcast');
    } catch (e) {
      AppLogger.service('Failed to acknowledge broadcast: $e', isError: true);
      if (e is HttpException) rethrow;
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  /// Get broadcast history (all broadcasts including acknowledged)
  Future<Map<String, dynamic>> getBroadcastHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      
      final queryParams = {
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      
      final uri = Uri.parse("$baseUrl$apiPrefix/broadcasts/history")
          .replace(queryParameters: queryParams);
      
      _logRequest('GET', '/broadcasts/history', headers: requestHeaders);

      final response = await _client.get(uri, headers: requestHeaders).timeout(timeout);

      _logResponse('/broadcasts/history', response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.service('✅ Broadcast history retrieved: ${data['total']} total');
        
        return {
          "success": true,
          "broadcasts": data['broadcasts'] ?? [],
          "total": data['total'] ?? 0,
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/broadcasts/history');
        throw HttpException("Authentication failed. Please login again.");
      }

      AppLogger.warning('Get broadcast history returned ${response.statusCode}');
      return {
        "success": false,
        "broadcasts": [],
        "total": 0,
      };
    } catch (e) {
      AppLogger.service('Failed to get broadcast history: $e', isError: true);
      if (e is HttpException && e.message.contains('Authentication failed')) rethrow;
      return {
        "success": false,
        "broadcasts": [],
        "total": 0,
      };
    }
  }

  /// Get all broadcasts (alias for getBroadcastHistory for backward compatibility)
  Future<Map<String, dynamic>> getAllBroadcasts({
    int limit = 50,
    int offset = 0,
  }) async {
    return getBroadcastHistory(limit: limit, offset: offset);
  }

  /// Get broadcast details by ID
  Future<Map<String, dynamic>> getBroadcastDetails(String broadcastId) async {
    await _ensureInitialized();
    
    try {
      final requestHeaders = await safeHeaders;
      
      _logRequest('GET', '/broadcast/$broadcastId', headers: requestHeaders);

      final response = await _client.get(
        Uri.parse("$baseUrl$apiPrefix/broadcast/$broadcastId"),
        headers: requestHeaders,
      ).timeout(timeout);

      _logResponse('/broadcast/$broadcastId', response.statusCode);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.service('✅ Broadcast details retrieved: $broadcastId');
        
        return {
          "success": true,
          "broadcast": data,
        };
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await handleAuthError(response.statusCode, '/broadcast/$broadcastId');
        throw HttpException("Authentication failed. Please login again.");
      } else if (response.statusCode == 404) {
        throw HttpException("Broadcast not found.");
      }

      throw HttpException("Failed to get broadcast details");
    } catch (e) {
      AppLogger.service('Failed to get broadcast details: $e', isError: true);
      if (e is HttpException) rethrow;
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  void dispose() {
    _client.close();
  }
}


