/// Broadcast model for emergency broadcasts and safety alerts
class Broadcast {
  final int? id; // Database ID
  final String broadcastId; // Unique broadcast ID like "BCAST-20251002-101151"
  final String type; // 'RADIUS', 'ZONE', 'REGION', 'ALL'
  final String title;
  final String message;
  final String severity; // 'LOW', 'MEDIUM', 'HIGH', 'CRITICAL'
  final String? alertType; // 'natural_disaster', 'security_threat', 'weather_warning', 'state_emergency'
  final String? actionRequired; // 'evacuate', 'stay_indoors', 'avoid_area', 'follow_instructions'
  final DateTime sentAt;
  final DateTime? expiresAt;
  final double? distanceKm;
  final bool isAcknowledged;
  final DateTime? acknowledgedAt;
  final String? acknowledgmentStatus; // 'safe', 'affected', 'need_help'
  final BroadcastSender? sentBy;
  final int? touristsNotified;
  final int? acknowledgments;
  final BroadcastLocation? center; // Center point for radius broadcasts
  final double? radiusKm;
  final Map<String, dynamic>? additionalData;

  Broadcast({
    this.id,
    required this.broadcastId,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    this.alertType,
    this.actionRequired,
    required this.sentAt,
    this.expiresAt,
    this.distanceKm,
    this.isAcknowledged = false,
    this.acknowledgedAt,
    this.acknowledgmentStatus,
    this.sentBy,
    this.touristsNotified,
    this.acknowledgments,
    this.center,
    this.radiusKm,
    this.additionalData,
  });

  factory Broadcast.fromJson(Map<String, dynamic> json) {
    return Broadcast(
      id: json['id'],
      broadcastId: json['broadcast_id'] ?? '',
      type: (json['broadcast_type'] ?? json['type'] ?? 'ALL').toString().toUpperCase(),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      severity: (json['severity'] ?? 'MEDIUM').toString().toUpperCase(),
      alertType: json['alert_type'],
      actionRequired: json['action_required'],
      sentAt: json['sent_at'] != null 
          ? DateTime.parse(json['sent_at'])
          : DateTime.now(),
      expiresAt: json['expires_at'] != null 
          ? DateTime.parse(json['expires_at'])
          : null,
      distanceKm: json['distance_km']?.toDouble(),
      isAcknowledged: json['is_acknowledged'] ?? false,
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'])
          : null,
      acknowledgmentStatus: json['acknowledgment_status'],
      sentBy: json['sent_by'] != null 
          ? BroadcastSender.fromJson(json['sent_by'])
          : null,
      touristsNotified: json['tourists_notified'],
      acknowledgments: json['acknowledgments'],
      center: json['center'] != null 
          ? BroadcastLocation.fromJson(json['center'])
          : null,
      radiusKm: json['radius_km']?.toDouble(),
      additionalData: json['additional_data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'broadcast_id': broadcastId,
      'type': type,
      'title': title,
      'message': message,
      'severity': severity,
      if (alertType != null) 'alert_type': alertType,
      if (actionRequired != null) 'action_required': actionRequired,
      'sent_at': sentAt.toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt?.toIso8601String(),
      if (distanceKm != null) 'distance_km': distanceKm,
      'is_acknowledged': isAcknowledged,
      if (acknowledgedAt != null) 'acknowledged_at': acknowledgedAt?.toIso8601String(),
      if (acknowledgmentStatus != null) 'acknowledgment_status': acknowledgmentStatus,
      if (sentBy != null) 'sent_by': sentBy?.toJson(),
      if (touristsNotified != null) 'tourists_notified': touristsNotified,
      if (acknowledgments != null) 'acknowledgments': acknowledgments,
      if (center != null) 'center': center?.toJson(),
      if (radiusKm != null) 'radius_km': radiusKm,
      if (additionalData != null) 'additional_data': additionalData,
    };
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isCritical => severity.toUpperCase() == 'CRITICAL';
  bool get isHigh => severity.toUpperCase() == 'HIGH';
  bool get isMedium => severity.toUpperCase() == 'MEDIUM';
  bool get isLow => severity.toUpperCase() == 'LOW';

  String get severityEmoji {
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return '🚨';
      case 'HIGH':
        return '⚠️';
      case 'MEDIUM':
        return '⚡';
      case 'LOW':
        return 'ℹ️';
      default:
        return '📢';
    }
  }

  String get alertTypeEmoji {
    switch (alertType?.toLowerCase()) {
      case 'natural_disaster':
        return '🌊';
      case 'security_threat':
        return '🚫';
      case 'weather_warning':
        return '⛈️';
      case 'state_emergency':
        return '🚨';
      default:
        return '📢';
    }
  }

  Broadcast copyWith({
    int? id,
    String? broadcastId,
    String? type,
    String? title,
    String? message,
    String? severity,
    String? alertType,
    String? actionRequired,
    DateTime? sentAt,
    DateTime? expiresAt,
    double? distanceKm,
    bool? isAcknowledged,
    DateTime? acknowledgedAt,
    String? acknowledgmentStatus,
    BroadcastSender? sentBy,
    int? touristsNotified,
    int? acknowledgments,
    BroadcastLocation? center,
    double? radiusKm,
    Map<String, dynamic>? additionalData,
  }) {
    return Broadcast(
      id: id ?? this.id,
      broadcastId: broadcastId ?? this.broadcastId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      alertType: alertType ?? this.alertType,
      actionRequired: actionRequired ?? this.actionRequired,
      sentAt: sentAt ?? this.sentAt,
      expiresAt: expiresAt ?? this.expiresAt,
      distanceKm: distanceKm ?? this.distanceKm,
      isAcknowledged: isAcknowledged ?? this.isAcknowledged,
      acknowledgedAt: acknowledgedAt ?? this.acknowledgedAt,
      acknowledgmentStatus: acknowledgmentStatus ?? this.acknowledgmentStatus,
      sentBy: sentBy ?? this.sentBy,
      touristsNotified: touristsNotified ?? this.touristsNotified,
      acknowledgments: acknowledgments ?? this.acknowledgments,
      center: center ?? this.center,
      radiusKm: radiusKm ?? this.radiusKm,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}

/// Broadcast sender information (police officer who sent the broadcast)
class BroadcastSender {
  final String id;
  final String? name;
  final String? department;

  BroadcastSender({
    required this.id,
    this.name,
    this.department,
  });

  factory BroadcastSender.fromJson(Map<String, dynamic> json) {
    return BroadcastSender(
      id: json['id'] ?? '',
      name: json['name'],
      department: json['department'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (name != null) 'name': name,
      if (department != null) 'department': department,
    };
  }
}

/// Location model for broadcast center points
class BroadcastLocation {
  final double lat;
  final double lon;

  BroadcastLocation({
    required this.lat,
    required this.lon,
  });

  factory BroadcastLocation.fromJson(Map<String, dynamic> json) {
    return BroadcastLocation(
      lat: (json['lat'] ?? json['latitude'] ?? 0.0).toDouble(),
      lon: (json['lon'] ?? json['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
    };
  }
}

/// Device registration model for push notifications
class DeviceRegistration {
  final String deviceToken;
  final String deviceType; // 'android' or 'ios'
  final String? deviceName;
  final String? appVersion;

  DeviceRegistration({
    required this.deviceToken,
    required this.deviceType,
    this.deviceName,
    this.appVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'device_token': deviceToken,
      'device_type': deviceType,
      if (deviceName != null) 'device_name': deviceName,
      if (appVersion != null) 'app_version': appVersion,
    };
  }
}

/// Broadcast acknowledgment model
class BroadcastAcknowledgment {
  final String status; // 'safe', 'affected', 'need_help'
  final double? lat;
  final double? lon;
  final String? notes;

  BroadcastAcknowledgment({
    required this.status,
    this.lat,
    this.lon,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
    };
  }
}
