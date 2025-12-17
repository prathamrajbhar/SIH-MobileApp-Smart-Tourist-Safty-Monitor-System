import 'package:latlong2/latlong.dart';

class LocationData {
  final String? touristId;
  final int? locationId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final int? safetyScore;
  final String? riskLevel;

  LocationData({
    this.touristId,
    this.locationId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.safetyScore,
    this.riskLevel,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      touristId: json['tourist_id'],
      locationId: json['location_id'] ?? json['id'],
      latitude: (json['latitude'] ?? json['lat']).toDouble(),
      longitude: (json['longitude'] ?? json['lon']).toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      accuracy: json['accuracy']?.toDouble(),
      altitude: json['altitude']?.toDouble(),
      speed: json['speed']?.toDouble(),
      heading: json['heading']?.toDouble(),
      safetyScore: json['safety_score'] != null 
          ? (json['safety_score'] is int 
              ? json['safety_score'] as int
              : (json['safety_score'] as double).round())
          : null,
      riskLevel: json['risk_level'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (touristId != null) 'tourist_id': touristId,
      if (locationId != null) 'location_id': locationId,
      'lat': latitude,
      'lon': longitude,
      'timestamp': timestamp.toIso8601String(),
      if (accuracy != null) 'accuracy': accuracy,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (safetyScore != null) 'safety_score': safetyScore,
      if (riskLevel != null) 'risk_level': riskLevel,
    };
  }
}

class SafetyScore {
  final String touristId;
  final int score;
  final String riskLevel;
  final Map<String, double> scoreBreakdown;
  final Map<String, double> componentWeights;
  final List<String> recommendations;
  final DateTime lastUpdated;

  SafetyScore({
    required this.touristId,
    required this.score,
    required this.riskLevel,
    required this.scoreBreakdown,
    required this.componentWeights,
    required this.recommendations,
    required this.lastUpdated,
  });

  String get level {
    if (score >= 80) return 'Safe';
    if (score >= 60) return 'Medium';
    return 'Risk';
  }

  String get levelColor {
    if (score >= 80) return 'green';
    if (score >= 60) return 'orange';
    return 'red';
  }

  String get description {
    if (score >= 80) return 'You are in a safe area';
    if (score >= 60) return 'Moderate safety level';
    return 'High risk area - be cautious';
  }

  factory SafetyScore.fromJson(Map<String, dynamic> json) {
    return SafetyScore(
      touristId: json['tourist_id'] ?? '',
      score: json['safety_score'] ?? 0,
      riskLevel: json['risk_level'] ?? 'unknown',
      scoreBreakdown: Map<String, double>.from(
        json['score_breakdown']?.map((k, v) => MapEntry(k, v.toDouble())) ?? {}
      ),
      componentWeights: Map<String, double>.from(
        json['component_weights']?.map((k, v) => MapEntry(k, v.toDouble())) ?? {}
      ),
      recommendations: List<String>.from(json['recommendations'] ?? []),
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tourist_id': touristId,
      'safety_score': score,
      'risk_level': riskLevel,
      'score_breakdown': scoreBreakdown,
      'component_weights': componentWeights,
      'recommendations': recommendations,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}
