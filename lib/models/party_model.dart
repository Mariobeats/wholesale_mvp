class PartyModel {
  final String id;
  final String shopName;
  final String ownerName;
  final String mobile;
  final String? address;
  final String? gstin;
  final String stateName;
  final String stateCode;
  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final DateTime? locationCapturedAt;
  final String? locationSource;
  final String? locationAddress;
  final DateTime? createdAt;

  PartyModel({
    required this.id,
    required this.shopName,
    required this.ownerName,
    required this.mobile,
    this.address,
    this.gstin,
    this.stateName = 'Madhya Pradesh',
    this.stateCode = '23',
    this.latitude,
    this.longitude,
    this.gpsAccuracy,
    this.locationCapturedAt,
    this.locationSource = 'gps',
    this.locationAddress,
    this.createdAt,
  });

  factory PartyModel.fromJson(Map<String, dynamic> json) {
    return PartyModel(
      id: json['id'].toString(),
      shopName: json['shop_name'] as String? ?? '',
      ownerName: json['owner_name'] as String? ?? '',
      mobile: json['mobile'] as String? ?? '',
      address: json['address'] as String?,
      gstin: json['gstin'] as String?,
      stateName: json['state_name'] as String? ?? 'Madhya Pradesh',
      stateCode: json['state_code'] as String? ?? '23',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      gpsAccuracy: (json['gps_accuracy'] as num?)?.toDouble(),
      locationCapturedAt: json['location_captured_at'] != null
          ? DateTime.tryParse(json['location_captured_at'].toString())
          : null,
      locationSource: json['location_source'] as String? ?? 'gps',
      locationAddress: json['location_address'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shop_name': shopName,
      'owner_name': ownerName,
      'mobile': mobile,
      'address': address,
      'gstin': gstin,
      'state_name': stateName,
      'state_code': stateCode,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (gpsAccuracy != null) 'gps_accuracy': gpsAccuracy,
      if (locationCapturedAt != null) 'location_captured_at': locationCapturedAt!.toIso8601String(),
      if (locationSource != null) 'location_source': locationSource,
      if (locationAddress != null) 'location_address': locationAddress,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  PartyModel copyWith({
    String? id,
    String? shopName,
    String? ownerName,
    String? mobile,
    String? address,
    String? gstin,
    String? stateName,
    String? stateCode,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    DateTime? locationCapturedAt,
    String? locationSource,
    String? locationAddress,
    DateTime? createdAt,
  }) {
    return PartyModel(
      id: id ?? this.id,
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      mobile: mobile ?? this.mobile,
      address: address ?? this.address,
      gstin: gstin ?? this.gstin,
      stateName: stateName ?? this.stateName,
      stateCode: stateCode ?? this.stateCode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      locationCapturedAt: locationCapturedAt ?? this.locationCapturedAt,
      locationSource: locationSource ?? this.locationSource,
      locationAddress: locationAddress ?? this.locationAddress,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
