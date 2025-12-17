/// E-FIR (Electronic First Information Report) model
/// For reporting incidents like harassment, theft, assault, etc.
class EFIR {
  final String? firNumber;
  final String? blockchainTxId;
  final String? referenceNumber;
  final String incidentDescription;
  final IncidentType incidentType;
  final String? location;
  final DateTime timestamp;
  final List<String> witnesses;
  final String? additionalDetails;
  final String? verificationUrl;
  final EFIRStatus status;
  final String? touristId;

  EFIR({
    this.firNumber,
    this.blockchainTxId,
    this.referenceNumber,
    required this.incidentDescription,
    required this.incidentType,
    this.location,
    required this.timestamp,
    this.witnesses = const [],
    this.additionalDetails,
    this.verificationUrl,
    this.status = EFIRStatus.draft,
    this.touristId,
  });

  factory EFIR.fromJson(Map<String, dynamic> json) {
    return EFIR(
      firNumber: json['fir_number'],
      blockchainTxId: json['blockchain_tx_id'],
      referenceNumber: json['reference_number'],
      incidentDescription: json['incident_description'] ?? '',
      incidentType: IncidentType.values.firstWhere(
        (e) => e.name == json['incident_type'],
        orElse: () => IncidentType.other,
      ),
      location: json['location'],
      timestamp: DateTime.parse(json['timestamp']),
      witnesses: json['witnesses'] != null 
          ? List<String>.from(json['witnesses']) 
          : [],
      additionalDetails: json['additional_details'],
      verificationUrl: json['verification_url'],
      status: EFIRStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EFIRStatus.submitted,
      ),
      touristId: json['tourist_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (firNumber != null) 'fir_number': firNumber,
      if (blockchainTxId != null) 'blockchain_tx_id': blockchainTxId,
      if (referenceNumber != null) 'reference_number': referenceNumber,
      'incident_description': incidentDescription,
      'incident_type': incidentType.name,
      if (location != null) 'location': location,
      'timestamp': timestamp.toIso8601String(),
      'witnesses': witnesses,
      if (additionalDetails != null) 'additional_details': additionalDetails,
      if (verificationUrl != null) 'verification_url': verificationUrl,
      'status': status.name,
      if (touristId != null) 'tourist_id': touristId,
    };
  }

  EFIR copyWith({
    String? firNumber,
    String? blockchainTxId,
    String? referenceNumber,
    String? incidentDescription,
    IncidentType? incidentType,
    String? location,
    DateTime? timestamp,
    List<String>? witnesses,
    String? additionalDetails,
    String? verificationUrl,
    EFIRStatus? status,
    String? touristId,
  }) {
    return EFIR(
      firNumber: firNumber ?? this.firNumber,
      blockchainTxId: blockchainTxId ?? this.blockchainTxId,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      incidentDescription: incidentDescription ?? this.incidentDescription,
      incidentType: incidentType ?? this.incidentType,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      witnesses: witnesses ?? this.witnesses,
      additionalDetails: additionalDetails ?? this.additionalDetails,
      verificationUrl: verificationUrl ?? this.verificationUrl,
      status: status ?? this.status,
      touristId: touristId ?? this.touristId,
    );
  }
}

/// Incident types for E-FIR
enum IncidentType {
  harassment,
  theft,
  assault,
  fraud,
  emergency,
  other;

  String get displayName {
    switch (this) {
      case IncidentType.harassment:
        return 'Harassment';
      case IncidentType.theft:
        return 'Theft';
      case IncidentType.assault:
        return 'Assault';
      case IncidentType.fraud:
        return 'Fraud';
      case IncidentType.emergency:
        return 'Emergency';
      case IncidentType.other:
        return 'Other';
    }
  }

  String get description {
    switch (this) {
      case IncidentType.harassment:
        return 'Verbal or physical harassment';
      case IncidentType.theft:
        return 'Theft or attempted theft';
      case IncidentType.assault:
        return 'Physical assault';
      case IncidentType.fraud:
        return 'Fraud or scam';
      case IncidentType.emergency:
        return 'Emergency situation';
      case IncidentType.other:
        return 'Other incidents';
    }
  }

  String get icon {
    switch (this) {
      case IncidentType.harassment:
        return '🚫';
      case IncidentType.theft:
        return '👜';
      case IncidentType.assault:
        return '⚠️';
      case IncidentType.fraud:
        return '💳';
      case IncidentType.emergency:
        return '🚨';
      case IncidentType.other:
        return '📝';
    }
  }
}

/// E-FIR status
enum EFIRStatus {
  draft,
  submitted,
  acknowledged,
  resolved;

  String get displayName {
    switch (this) {
      case EFIRStatus.draft:
        return 'Draft';
      case EFIRStatus.submitted:
        return 'Submitted';
      case EFIRStatus.acknowledged:
        return 'Acknowledged';
      case EFIRStatus.resolved:
        return 'Resolved';
    }
  }
}
