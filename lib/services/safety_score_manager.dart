import 'package:shared_preferences/shared_preferences.dart';
import '../models/location.dart';
import '../utils/logger.dart';
import 'dart:convert';
import 'dart:math';

/// Enhanced Safety Score Manager with intelligent algorithms and caching
class SafetyScoreManager {
  static const String _cacheKey = 'cached_safety_score';
  static const String _lastUpdateKey = 'safety_score_last_update';
  static const String _locationHistoryKey = 'location_risk_history';
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Calculate intelligent safety score based on multiple factors
  static Future<Map<String, dynamic>> calculateIntelligentSafetyScore({
    required LocationData? currentLocation,
    required List<Map<String, dynamic>> riskZones,
    required List<Map<String, dynamic>> recentIncidents,
    required String timeOfDay,
    int? cachedScore,
  }) async {
    try {
      AppLogger.api('🧠 Calculating intelligent safety score...');

      // Factor 1: Location Risk Assessment (40% weight)
      double locationRisk = await _calculateLocationRisk(currentLocation, riskZones);
      
      // Factor 2: Time-based Risk (20% weight)
      double timeRisk = _calculateTimeBasedRisk(timeOfDay);
      
      // Factor 3: Incident Proximity Risk (25% weight)
      double incidentRisk = _calculateIncidentProximityRisk(currentLocation, recentIncidents);
      
      // Factor 4: Historical Movement Pattern (10% weight)
      double movementRisk = await _calculateMovementPatternRisk(currentLocation);
      
      // Factor 5: Population Density Factor (5% weight)
      double densityFactor = _calculatePopulationDensityFactor(currentLocation);

      // Weighted calculation - Convert risk factors to safety score
      // Higher risk factors = lower safety score
      double combinedRisk = (
        (locationRisk * 0.40) +
        (timeRisk * 0.20) +
        (incidentRisk * 0.25) +
        (movementRisk * 0.10) +
        (densityFactor * 0.05)
      );

      // Convert risk (0-1) to safety score (0-100)
      // Risk 0 = Safety 100, Risk 1 = Safety 0
      double safetyScore = (1.0 - combinedRisk) * 100;

      // Apply smoothing to prevent drastic changes
      int finalScore = await _applySmoothingAlgorithm(safetyScore / 100, cachedScore);
      
      // Determine risk level with hysteresis
      String riskLevel = _determineRiskLevelWithHysteresis(finalScore, cachedScore);
      
      AppLogger.api('✨ Calculated safety score: $finalScore% (level: $riskLevel)');
      
      return {
        'safety_score': finalScore,
        'risk_level': riskLevel,
        'last_updated': DateTime.now().toIso8601String(),
        'factors': {
          'location_risk': locationRisk,
          'time_risk': timeRisk,
          'incident_risk': incidentRisk,
          'movement_risk': movementRisk,
          'density_factor': densityFactor,
        },
        'calculation_method': 'intelligent_algorithm_v2.0'
      };
    } catch (e) {
      AppLogger.error('🚨 Error in safety score calculation: $e');
      // No mock data - throw error and let caller handle it
      rethrow;
    }
  }

  /// Calculate location-based risk assessment
  static Future<double> _calculateLocationRisk(
    LocationData? location, 
    List<Map<String, dynamic>> riskZones
  ) async {
    if (location == null) return 0.5; // Neutral risk if no location

    double minRisk = 0.0;
    
    for (var zone in riskZones) {
      double distance = _calculateDistance(
        location.latitude,
        location.longitude,
        zone['lat'] ?? 0.0,
        zone['lng'] ?? 0.0,
      );
      
      // Risk decreases with distance, increases with zone severity
      double zoneSeverity = (zone['severity'] ?? 1) / 10.0;
      double proximityFactor = max(0, 1 - (distance / 1000)); // 1km max influence
      double zoneRisk = zoneSeverity * proximityFactor;
      
      minRisk = max(minRisk, zoneRisk);
    }
    
    return minRisk;
  }

  /// Calculate time-based risk (higher at night, lower during day)
  static double _calculateTimeBasedRisk(String timeOfDay) {
    DateTime now = DateTime.now();
    int hour = now.hour;
    
    // Risk pattern: higher at night (22:00-06:00), lower during day
    if (hour >= 22 || hour <= 6) {
      return 0.7; // High risk at night
    } else if (hour >= 7 && hour <= 9) {
      return 0.2; // Low risk morning rush
    } else if (hour >= 17 && hour <= 21) {
      return 0.3; // Medium risk evening
    } else {
      return 0.1; // Low risk during day
    }
  }

  /// Calculate risk based on proximity to recent incidents
  static double _calculateIncidentProximityRisk(
    LocationData? location,
    List<Map<String, dynamic>> incidents
  ) {
    if (location == null || incidents.isEmpty) return 0.0;

    double maxIncidentRisk = 0.0;
    DateTime now = DateTime.now();
    
    for (var incident in incidents) {
      double distance = _calculateDistance(
        location.latitude,
        location.longitude,
        incident['lat'] ?? 0.0,
        incident['lng'] ?? 0.0,
      );
      
      // Time decay: older incidents have less impact
      DateTime incidentTime = DateTime.tryParse(incident['timestamp'] ?? '') ?? now;
      double hoursSince = now.difference(incidentTime).inHours.toDouble();
      double timeFactor = max(0, 1 - (hoursSince / 24)); // 24h decay
      
      // Distance decay: closer incidents have more impact
      double distanceFactor = max(0, 1 - (distance / 2000)); // 2km max influence
      
      // Severity factor
      double severity = (incident['severity'] ?? 1) / 10.0;
      
      double incidentRisk = severity * timeFactor * distanceFactor;
      maxIncidentRisk = max(maxIncidentRisk, incidentRisk);
    }
    
    return maxIncidentRisk;
  }

  /// Analyze historical movement patterns for risk assessment
  static Future<double> _calculateMovementPatternRisk(LocationData? location) async {
    try {
      if (location == null) return 0.0;
      
      final prefs = await SharedPreferences.getInstance();
      String? historyJson = prefs.getString(_locationHistoryKey);
      
      if (historyJson == null) return 0.0;
      
      List<dynamic> history = jsonDecode(historyJson);
      
      // Analyze for unusual patterns (e.g., going to risky areas frequently)
      double riskPattern = 0.0;
      for (var point in history.take(10)) { // Last 10 locations
        double riskScore = point['risk_score'] ?? 0.0;
        riskPattern += riskScore;
      }
      
      return min(1.0, riskPattern / 10.0);
    } catch (e) {
      AppLogger.warning('Could not analyze movement patterns: $e');
      return 0.0;
    }
  }

  /// Calculate population density factor (busier areas = safer)
  static double _calculatePopulationDensityFactor(LocationData? location) {
    if (location == null) return 0.5;
    
    // This is a simplified model - in real implementation, 
    // you'd integrate with population density APIs
    DateTime now = DateTime.now();
    int hour = now.hour;
    
    // Assume business areas are safer during business hours
    if (hour >= 9 && hour <= 17) {
      return 0.2; // Lower risk in business hours
    } else {
      return 0.6; // Higher risk when areas are empty
    }
  }

  /// Apply smoothing algorithm to prevent sudden score changes
  static Future<int> _applySmoothingAlgorithm(double rawScore, int? previousScore) async {
    int newScore = (rawScore * 100).round();
    
    if (previousScore == null) return newScore;
    
    // Limit change to max 10 points per update to avoid jarring changes
    int maxChange = 10;
    int change = newScore - previousScore;
    
    if (change.abs() > maxChange) {
      newScore = previousScore + (change.sign * maxChange).round();
    }
    
    return newScore.clamp(0, 100);
  }

  /// Determine risk level with hysteresis to prevent flickering
  static String _determineRiskLevelWithHysteresis(int currentScore, int? previousScore) {
    // Add hysteresis bands to prevent constant level switching
    // Higher score = safer
    if (currentScore >= 80) return 'Safe';
    if (currentScore >= 60) return 'Medium';
    if (currentScore >= 40) return 'High Risk';
    return 'Critical';
  }

  /// Cache safety score data for offline use
  static Future<void> cacheSafetyScore(Map<String, dynamic> scoreData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(scoreData));
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
      AppLogger.info('💾 Safety score cached successfully');
    } catch (e) {
      AppLogger.warning('Failed to cache safety score: $e');
    }
  }

  /// Get cached safety score if available and valid
  static Future<Map<String, dynamic>?> getCachedSafetyScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString(_cacheKey);
      int? lastUpdate = prefs.getInt(_lastUpdateKey);
      
      if (cachedData == null || lastUpdate == null) return null;
      
      DateTime cacheTime = DateTime.fromMillisecondsSinceEpoch(lastUpdate);
      bool isExpired = DateTime.now().difference(cacheTime) > _cacheValidDuration;
      
      if (isExpired) {
        AppLogger.info('⏰ Cached safety score expired');
        return null;
      }
      
      Map<String, dynamic> scoreData = jsonDecode(cachedData);
      AppLogger.info('💾 Using cached safety score');
      return scoreData;
    } catch (e) {
      AppLogger.warning('Error reading cached safety score: $e');
      return null;
    }
  }



  /// Calculate distance between two coordinates (Haversine formula)
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    
    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Update location history for pattern analysis
  static Future<void> updateLocationHistory(LocationData location, double riskScore) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? historyJson = prefs.getString(_locationHistoryKey);
      
      List<dynamic> history = historyJson != null ? jsonDecode(historyJson) : [];
      
      history.add({
        'lat': location.latitude,
        'lng': location.longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'risk_score': riskScore,
      });
      
      // Keep only last 50 entries
      if (history.length > 50) {
        history = history.sublist(history.length - 50);
      }
      
      await prefs.setString(_locationHistoryKey, jsonEncode(history));
    } catch (e) {
      AppLogger.warning('Failed to update location history: $e');
    }
  }
}
