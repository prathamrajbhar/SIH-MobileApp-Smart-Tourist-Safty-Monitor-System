/// Notification model for push notifications and SMS alerts
class NotificationData {
  final String id;
  final String type; // 'push', 'sms', 'email'
  final String? userId;
  final String? phoneNumber;
  final String title;
  final String message;
  final String status; // 'sent', 'delivered', 'failed'
  final DateTime sentAt;
  final DateTime? deliveredAt;
  final Map<String, dynamic>? data;
  final String? messageId;
  final String? cost;

  NotificationData({
    required this.id,
    required this.type,
    this.userId,
    this.phoneNumber,
    required this.title,
    required this.message,
    required this.status,
    required this.sentAt,
    this.deliveredAt,
    this.data,
    this.messageId,
    this.cost,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      id: json['id'] ?? '',
      type: json['type'] ?? 'push',
      userId: json['user_id'],
      phoneNumber: json['phone_number'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      status: json['status'] ?? 'sent',
      sentAt: DateTime.parse(json['sent_at']),
      deliveredAt: json['delivered_at'] != null 
          ? DateTime.parse(json['delivered_at'])
          : null,
      data: json['data'],
      messageId: json['message_id'] ?? json['message_sid'],
      cost: json['cost'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'user_id': userId,
      'phone_number': phoneNumber,
      'title': title,
      'message': message,
      'status': status,
      'sent_at': sentAt.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'data': data,
      'message_id': messageId,
      'cost': cost,
    };
  }

  bool get isDelivered => status == 'delivered';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'sent';
}

/// Restricted Zone model for geofencing
class RestrictedZone {
  final int id;
  final String name;
  final String description;
  final String zoneType; // 'safe', 'risky', 'restricted'
  final double? centerLatitude;
  final double? centerLongitude;
  final double? radiusMeters;
  final List<List<double>>? coordinates; // For polygon zones
  final bool isActive;
  final String? createdBy;
  final DateTime createdAt;

  RestrictedZone({
    required this.id,
    required this.name,
    required this.description,
    required this.zoneType,
    this.centerLatitude,
    this.centerLongitude,
    this.radiusMeters,
    this.coordinates,
    required this.isActive,
    this.createdBy,
    required this.createdAt,
  });

  factory RestrictedZone.fromJson(Map<String, dynamic> json) {
    return RestrictedZone(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      zoneType: json['zone_type'] ?? json['type'] ?? 'restricted',
      centerLatitude: json['center_latitude']?.toDouble(),
      centerLongitude: json['center_longitude']?.toDouble(),
      radiusMeters: json['radius_meters']?.toDouble(),
      coordinates: json['coordinates'] != null
          ? List<List<double>>.from(
              json['coordinates'].map((coord) => List<double>.from(coord))
            )
          : null,
      isActive: json['is_active'] ?? true,
      createdBy: json['created_by'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'zone_type': zoneType,
      'center_latitude': centerLatitude,
      'center_longitude': centerLongitude,
      'radius_meters': radiusMeters,
      'coordinates': coordinates,
      'is_active': isActive,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isSafe => zoneType == 'safe';
  bool get isRisky => zoneType == 'risky';
  bool get isRestricted => zoneType == 'restricted';

  String get displayColor {
    switch (zoneType) {
      case 'safe':
        return '#4CAF50'; // Green
      case 'risky':
        return '#FF9800'; // Orange
      case 'restricted':
        return '#F44336'; // Red
      default:
        return '#9E9E9E'; // Gray
    }
  }
}

/// Nearby Zone model for proximity alerts
class NearbyZone {
  final int id;
  final String name;
  final String type;
  final double distanceMeters;
  final String description;

  NearbyZone({
    required this.id,
    required this.name,
    required this.type,
    required this.distanceMeters,
    required this.description,
  });

  factory NearbyZone.fromJson(Map<String, dynamic> json) {
    return NearbyZone(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? 'unknown',
      distanceMeters: (json['distance_meters'] ?? 0).toDouble(),
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'distance_meters': distanceMeters,
      'description': description,
    };
  }

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toInt()} m';
    } else {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
  }
}

/// SOS Alert model for emergency responses
class SOSAlert {
  final String alertId;
  final String incidentNumber;
  final List<String> emergencyContactsNotified;
  final bool authoritiesNotified;
  final String estimatedResponseTime;
  final String? message;
  final String? locationDescription;
  final DateTime triggeredAt;

  SOSAlert({
    required this.alertId,
    required this.incidentNumber,
    required this.emergencyContactsNotified,
    required this.authoritiesNotified,
    required this.estimatedResponseTime,
    this.message,
    this.locationDescription,
    required this.triggeredAt,
  });

  factory SOSAlert.fromJson(Map<String, dynamic> json) {
    return SOSAlert(
      alertId: json['alert_id'] ?? '',
      incidentNumber: json['incident_number'] ?? '',
      emergencyContactsNotified: List<String>.from(
        json['emergency_contacts_notified'] ?? []
      ),
      authoritiesNotified: json['authorities_notified'] ?? false,
      estimatedResponseTime: json['estimated_response_time'] ?? '',
      message: json['message'],
      locationDescription: json['location_description'],
      triggeredAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alert_id': alertId,
      'incident_number': incidentNumber,
      'emergency_contacts_notified': emergencyContactsNotified,
      'authorities_notified': authoritiesNotified,
      'estimated_response_time': estimatedResponseTime,
      'message': message,
      'location_description': locationDescription,
      'triggered_at': triggeredAt.toIso8601String(),
    };
  }
}

/// Geofence Check Result model
class GeofenceCheckResult {
  final bool insideRestricted;
  final List<RestrictedZone> zones;
  final String riskLevel;
  final int zoneCount;

  GeofenceCheckResult({
    required this.insideRestricted,
    required this.zones,
    required this.riskLevel,
    required this.zoneCount,
  });

  factory GeofenceCheckResult.fromJson(Map<String, dynamic> json) {
    return GeofenceCheckResult(
      insideRestricted: json['inside_restricted'] ?? false,
      zones: (json['zones'] as List<dynamic>?)
          ?.map((zone) => RestrictedZone.fromJson(zone))
          .toList() ?? [],
      riskLevel: json['risk_level'] ?? 'safe',
      zoneCount: json['zone_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inside_restricted': insideRestricted,
      'zones': zones.map((zone) => zone.toJson()).toList(),
      'risk_level': riskLevel,
      'zone_count': zoneCount,
    };
  }
}
