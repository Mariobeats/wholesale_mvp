class OrderItemModel {
  final String? id;
  final String? orderId;
  final String productId;
  final String? productName;
  final int quantity;
  final double price;
  final String hsnCode;
  final int pcsPerBox;
  final String unit;
  final double discountPercent;
  final double gstRate;
  final String? remark;

  OrderItemModel({
    this.id,
    this.orderId,
    required this.productId,
    this.productName,
    required this.quantity,
    required this.price,
    this.hsnCode = '21069099',
    this.pcsPerBox = 90,
    this.unit = 'PCS',
    this.discountPercent = 3.0,
    this.gstRate = 5.0,
    this.remark,
  });

  double get grossAmount => quantity * price;
  double get discountAmount => grossAmount * (discountPercent / 100);
  double get totalPrice => grossAmount - discountAmount;
  int get boxCount => pcsPerBox > 0 ? (quantity / pcsPerBox).floor() : 0;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    String? prodName;
    String? hsn;
    int? boxPcs;
    String? unitStr;
    double? gst;

    if (json['products'] != null && json['products'] is Map) {
      final pMap = json['products'] as Map;
      prodName = pMap['name'] as String?;
      hsn = pMap['hsn_code'] as String?;
      boxPcs = (pMap['pcs_per_box'] as num?)?.toInt();
      unitStr = pMap['unit'] as String?;
      gst = (pMap['gst_rate'] as num?)?.toDouble();
    }

    return OrderItemModel(
      id: json['id']?.toString(),
      orderId: json['order_id']?.toString(),
      productId: json['product_id'].toString(),
      productName: prodName ?? json['product_name'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      hsnCode: hsn ?? json['hsn_code'] as String? ?? '21069099',
      pcsPerBox: boxPcs ?? (json['pcs_per_box'] as num?)?.toInt() ?? 90,
      unit: unitStr ?? json['unit'] as String? ?? 'PCS',
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ?? 3.0,
      gstRate: gst ?? (json['gst_rate'] as num?)?.toDouble() ?? 5.0,
      remark: json['remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      'product_id': productId,
      'quantity': quantity,
      'price': price,
      if (remark != null && remark!.isNotEmpty) 'remark': remark,
    };
  }
}

