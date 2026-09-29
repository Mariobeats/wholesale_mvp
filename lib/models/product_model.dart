class ProductModel {
  final String id;
  final String name;
  final double price;
  final int stock;
  final String hsnCode;
  final double gstRate;
  final int pcsPerBox;
  final String unit;
  final DateTime? createdAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.hsnCode = '21069099',
    this.gstRate = 5.0,
    this.pcsPerBox = 1,
    this.unit = 'PCS',
    this.createdAt,
  });

  bool get isOutOfStock => stock <= 0;
  bool get isLowStock => stock > 0 && stock <= 10;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'].toString(),
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      hsnCode: json['hsn_code'] as String? ?? '21069099',
      gstRate: (json['gst_rate'] as num?)?.toDouble() ?? 5.0,
      pcsPerBox: (json['pcs_per_box'] as num?)?.toInt() ?? 1,
      unit: json['unit'] as String? ?? 'PCS',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'stock': stock,
      'hsn_code': hsnCode,
      'gst_rate': gstRate,
      'pcs_per_box': pcsPerBox,
      'unit': unit,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    double? price,
    int? stock,
    String? hsnCode,
    double? gstRate,
    int? pcsPerBox,
    String? unit,
    DateTime? createdAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      stock: stock ?? this.stock,
      hsnCode: hsnCode ?? this.hsnCode,
      gstRate: gstRate ?? this.gstRate,
      pcsPerBox: pcsPerBox ?? this.pcsPerBox,
      unit: unit ?? this.unit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

