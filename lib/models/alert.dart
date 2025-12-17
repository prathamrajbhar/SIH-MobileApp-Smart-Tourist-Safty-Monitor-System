import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class Alert {
  final int id;
  final String touristId;
  final String touristName;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String description;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final bool isAcknowledged;
  final String? acknowledgedBy;
  final DateTime? acknowledgedAt;
  final bool isResolved;
  final DateTime? resolvedAt;

  Alert({
    required this.id,
    required this.touristId,
    required this.touristName,
    required this.type,
    required this.severity,
    required this.title,
    required this.description,
    this.latitude,
    this.longitude,
    required this.createdAt,
    this.isAcknowledged = false,
    this.acknowledgedBy,
    this.acknowledgedAt,
    this.isResolved = false,
    this.resolvedAt,
  });

  LatLng? get location {
    if (latitude != null && longitude != null) {
      return LatLng(latitude!, longitude!);
    }
    return null;
  }

  /// Parse latitude from various possible JSON formats
  static double? _parseLatitude(Map<String, dynamic> json) {
    double? lat;
    
    // Try direct fields first
    if (json['latitude'] != null) {
      lat = json['latitude']?.toDouble();
      print('[COORD] Found direct latitude: $lat');
      return lat;
    }
    if (json['lat'] != null) {
      lat = json['lat']?.toDouble();
      print('[COORD] Found direct lat: $lat');
      return lat;
    }
    
    // Try nested location object
    final location = json['location'];
    if (location is Map<String, dynamic>) {
      if (location['lat'] != null) {
        lat = location['lat']?.toDouble();
        print('[COORD] Found nested location.lat: $lat');
        return lat;
      }
      if (location['latitude'] != null) {
        lat = location['latitude']?.toDouble();
        print('[COORD] Found nested location.latitude: $lat');
        return lat;
      }
    }
    
    print('[COORD] No latitude found in: ${json.keys.toList()}');
    return null;
  }

  /// Parse longitude from various possible JSON formats
  static double? _parseLongitude(Map<String, dynamic> json) {
    double? lng;
    
    // Try direct fields first
    if (json['longitude'] != null) {
      lng = json['longitude']?.toDouble();
      print('[COORD] Found direct longitude: $lng');
      return lng;
    }
    if (json['lon'] != null) {
      lng = json['lon']?.toDouble();
      print('[COORD] Found direct lon: $lng');
      return lng;
    }
    if (json['lng'] != null) {
      lng = json['lng']?.toDouble();
      print('[COORD] Found direct lng: $lng');
      return lng;
    }
    
    // Try nested location object
    final location = json['location'];
    if (location is Map<String, dynamic>) {
      if (location['lon'] != null) {
        lng = location['lon']?.toDouble();
        print('[COORD] Found nested location.lon: $lng');
        return lng;
      }
      if (location['lng'] != null) {
        lng = location['lng']?.toDouble();
        print('[COORD] Found nested location.lng: $lng');
        return lng;
      }
      if (location['longitude'] != null) {
        lng = location['longitude']?.toDouble();
        print('[COORD] Found nested location.longitude: $lng');
        return lng;
      }
    }
    
    print('[COORD] No longitude found in: ${json.keys.toList()}');
    return null;
  }

  factory Alert.fromJson(Map<String, dynamic> json) {
    // Handle both API and mock data formats
    final alertId = json['alert_id'] ?? json['id'] ?? 0;
    final touristId = json['tourist_id'] ?? json['user_id'] ?? '';
    final touristName = json['tourist_name'] ?? 'Unknown Tourist';
    
    // Parse timestamp from various formats
    DateTime createdAt;
    try {
      if (json['timestamp'] != null) {
        createdAt = DateTime.parse(json['timestamp']);
      } else if (json['created_at'] != null) {
        createdAt = DateTime.parse(json['created_at']);
      } else {
        createdAt = DateTime.now(); // Fallback to current time
      }
    } catch (e) {
      print('[ALERT] Error parsing timestamp: ${json['timestamp']} - $e');
      createdAt = DateTime.now(); // Fallback to current time
    }
    
    // Parse alert type
    AlertType alertType;
    final typeStr = json['type']?.toString().toLowerCase() ?? 'general';
    if (typeStr == 'sos' || typeStr == 'panic') {
      alertType = AlertType.sos;
    } else if (typeStr == 'emergency') {
      alertType = AlertType.emergency;
    } else if (typeStr == 'geofence') {
      alertType = AlertType.geofence;
    } else if (typeStr == 'anomaly') {
      alertType = AlertType.anomaly;
    } else if (typeStr == 'sequence') {
      alertType = AlertType.sequence;
    } else if (typeStr == 'safety') {
      alertType = AlertType.safety;
    } else {
      alertType = AlertType.general;
    }
    
    // Parse severity
    AlertSeverity alertSeverity;
    final severityStr = json['severity']?.toString().toLowerCase() ?? 'medium';
    if (severityStr == 'critical') {
      alertSeverity = AlertSeverity.critical;
    } else if (severityStr == 'high') {
      alertSeverity = AlertSeverity.high;
    } else if (severityStr == 'low') {
      alertSeverity = AlertSeverity.low;
    } else {
      alertSeverity = AlertSeverity.medium;
    }
    
    return Alert(
      id: alertId,
      touristId: touristId,
      touristName: touristName,
      type: alertType,
      severity: alertSeverity,
      title: json['title'] ?? 'Alert',
      description: json['description'] ?? json['message'] ?? 'No description available',
      latitude: _parseLatitude(json),
      longitude: _parseLongitude(json),
      createdAt: createdAt,
      isAcknowledged: json['is_acknowledged'] ?? false,
      acknowledgedBy: json['acknowledged_by'],
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.tryParse(json['acknowledged_at'])
          : null,
      isResolved: json['resolved'] ?? json['is_resolved'] ?? false,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tourist_id': touristId,
      'tourist_name': touristName,
      'type': type.name,
      'severity': severity.name,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.toIso8601String(),
      'is_acknowledged': isAcknowledged,
      'acknowledged_by': acknowledgedBy,
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
      'is_resolved': isResolved,
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  Alert copyWith({
    int? id,
    String? touristId,
    String? touristName,
    AlertType? type,
    AlertSeverity? severity,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
    bool? isAcknowledged,
    String? acknowledgedBy,
    DateTime? acknowledgedAt,
    bool? isResolved,
    DateTime? resolvedAt,
  }) {
    return Alert(
      id: id ?? this.id,
      touristId: touristId ?? this.touristId,
      touristName: touristName ?? this.touristName,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      acknowledgedBy: acknowledgedBy ?? this.acknowledgedBy,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

enum AlertType {
  sos,
  geofence,
  anomaly,
  sequence,
  safety,
  general,
  emergency,
}

enum AlertSeverity {
  low,
  medium,
  high,
  critical,
}

class RestrictedZone {
  final String id;
  final String name;
  final String description;
  final List<LatLng> polygonCoordinates;
  final ZoneType type;
  final String? warningMessage;
  final LatLng? center;
  final double? radiusMeters;
  final String? safetyRecommendation;

  RestrictedZone({
    required this.id,
    required this.name,
    required this.description,
    required this.polygonCoordinates,
    required this.type,
    this.warningMessage,
    this.center,
    this.radiusMeters,
    this.safetyRecommendation,
  });

  factory RestrictedZone.fromJson(Map<String, dynamic> json) {
    List<LatLng> coordinates = [];
    LatLng? centerPoint;
    double? radius;
    
    // Handle the actual API response format with center and radius
    if (json['center'] != null && json['center']['lat'] != null && json['center']['lon'] != null) {
      centerPoint = LatLng(
        json['center']['lat'].toDouble(),
        json['center']['lon'].toDouble(),
      );
      radius = json['radius_meters']?.toDouble() ?? 1000.0;
      
      // Generate circular polygon from center and radius
      coordinates = _generateCircularPolygon(centerPoint, radius!);
    } else if (json['polygon_coordinates'] != null) {
      // Handle polygon coordinates if provided
      for (var coord in json['polygon_coordinates']) {
        coordinates.add(LatLng(coord['lat'].toDouble(), coord['lon'].toDouble()));
      }
    } else {
      // No coordinates provided by API - throw error instead of using mock data
      throw FormatException(
        'RestrictedZone API response must include either center+radius or polygon_coordinates. Zone ID: ${json['id']}'
      );
    }

    return RestrictedZone(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown Zone',
      description: json['description'] ?? '',
      polygonCoordinates: coordinates,
      type: _parseZoneType(json['type']),
      warningMessage: json['warning_message'] ?? json['safety_recommendation'],
      center: centerPoint,
      radiusMeters: radius,
      safetyRecommendation: json['safety_recommendation'],
    );
  }

  static ZoneType _parseZoneType(dynamic type) {
    if (type == null) return ZoneType.restricted;
    
    String typeStr = type.toString().toLowerCase();
    switch (typeStr) {
      case 'restricted':
        return ZoneType.restricted;
      case 'high_risk':
      case 'highrisk':
      case 'high-risk':
      case 'risky':
        return ZoneType.highRisk;
      case 'dangerous':
        return ZoneType.dangerous;
      case 'caution':
      case 'safe':
        return ZoneType.caution;
      default:
        return ZoneType.restricted;
    }
  }

  static List<LatLng> _generateCircularPolygon(LatLng center, double radiusMeters) {
    // Convert radius from meters to degrees (approximate)
    // 1 degree ≈ 111,000 meters at equator
    double radiusInDegrees = radiusMeters / 111000.0;
    
    List<LatLng> polygon = [];
    int numPoints = 16; // More points for smoother circle
    
    for (int i = 0; i < numPoints; i++) {
      double angle = (i * 360 / numPoints) * (math.pi / 180);
      double lat = center.latitude + radiusInDegrees * math.cos(angle);
      double lon = center.longitude + radiusInDegrees * math.sin(angle) / math.cos(center.latitude * (math.pi / 180));
      polygon.add(LatLng(lat, lon));
    }
    
    return polygon;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'polygon_coordinates': polygonCoordinates
          .map((coord) => {'lat': coord.latitude, 'lon': coord.longitude})
          .toList(),
      'type': type.name,
      'warning_message': warningMessage,
    };
  }
}

enum ZoneType {
  restricted,
  highRisk,
  dangerous,
  caution,
  safe, // Added safe zone type to match API response
}

class PanicAlert {
  final String touristId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String? message;
  final bool isActive;

  PanicAlert({
    required this.touristId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.message,
    this.isActive = true,
  });

  LatLng get location => LatLng(latitude, longitude);

  factory PanicAlert.fromJson(Map<String, dynamic> json) {
    return PanicAlert(
      touristId: json['tourist_id'],
      latitude: json['lat'].toDouble(),
      longitude: json['lon'].toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      message: json['message'],
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tourist_id': touristId,
      'lat': latitude,
      'lon': longitude,
      'timestamp': timestamp.toIso8601String(),
      'message': message,
      'is_active': isActive,
    };
  }
}
