class Tourist {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final int safetyScore;
  final String riskLevel;
  final DateTime? lastSeen;
  final String? emergencyContact;
  final String? emergencyPhone;
  final DateTime? registrationDate;
  final bool isActive;
  final double? lastLocationLat;
  final double? lastLocationLon;
  final String? token;

  Tourist({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.safetyScore = 50,
    this.riskLevel = 'unknown',
    this.lastSeen,
    this.emergencyContact,
    this.emergencyPhone,
    this.registrationDate,
    this.isActive = true,
    this.lastLocationLat,
    this.lastLocationLon,
    this.token,
  });

  factory Tourist.fromJson(Map<String, dynamic> json) {
    return Tourist(
      id: json['user_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      safetyScore: json['safety_score'] ?? 50,
      riskLevel: json['risk_level'] ?? 'unknown',
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'])
          : null,
      emergencyContact: json['emergency_contact'],
      emergencyPhone: json['emergency_phone'],
      registrationDate: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      isActive: json['is_active'] ?? true,
      lastLocationLat: json['last_location_lat']?.toDouble(),
      lastLocationLon: json['last_location_lon']?.toDouble(),
      token: json['access_token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'safety_score': safetyScore,
      'risk_level': riskLevel,
      'last_seen': lastSeen?.toIso8601String(),
      'emergency_contact': emergencyContact,
      'emergency_phone': emergencyPhone,
      'created_at': registrationDate?.toIso8601String(),
      'is_active': isActive,
      'last_location_lat': lastLocationLat,
      'last_location_lon': lastLocationLon,
    };
  }

  Tourist copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    int? safetyScore,
    String? riskLevel,
    DateTime? lastSeen,
    String? emergencyContact,
    String? emergencyPhone,
    DateTime? registrationDate,
    bool? isActive,
    double? lastLocationLat,
    double? lastLocationLon,
    String? token,
  }) {
    return Tourist(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      safetyScore: safetyScore ?? this.safetyScore,
      riskLevel: riskLevel ?? this.riskLevel,
      lastSeen: lastSeen ?? this.lastSeen,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      registrationDate: registrationDate ?? this.registrationDate,
      isActive: isActive ?? this.isActive,
      lastLocationLat: lastLocationLat ?? this.lastLocationLat,
      lastLocationLon: lastLocationLon ?? this.lastLocationLon,
      token: token ?? this.token,
    );
  }

  String get safetyLevel {
    if (safetyScore >= 80) return 'Safe';
    if (safetyScore >= 60) return 'Medium';
    return 'Risk';
  }

  String get safetyDescription {
    if (safetyScore >= 80) return 'You are in a safe area';
    if (safetyScore >= 60) return 'Moderate safety level';
    return 'High risk area - be cautious';
  }

  /// Get safety color based on score
  /// Green for safe (>80), Orange for medium (60-79), Red for risk (<60)
  String get safetyColor {
    if (safetyScore >= 80) return '#4CAF50'; // Green
    if (safetyScore >= 60) return '#FF9800'; // Orange  
    return '#F44336'; // Red
  }

  /// Generate registration payload for API
  Map<String, dynamic> toRegistrationJson() {
    return {
      'email': email,
      'name': name,
      'phone': phone,
      'emergency_contact': emergencyContact,
      'emergency_phone': emergencyPhone,
    };
  }

  /// Generate login payload for API
  Map<String, dynamic> toLoginJson(String password) {
    return {
      'email': email,
      'password': password,
    };
  }
}
