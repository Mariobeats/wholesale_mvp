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
      locationAddress: locationAddress ?? this.locationAddress,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

