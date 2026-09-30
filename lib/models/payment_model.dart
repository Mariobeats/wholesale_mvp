class PaymentModel {
  final String id;
  final String partyId;
  final String? partyShopName;
  final String salesmanId;
  final String? salesmanName;
  final double amount;
  final String paymentMode; // 'cash', 'upi', 'cheque', 'bank_transfer'
  final String? referenceNo;
  final String? remarks;
  final DateTime? createdAt;

  PaymentModel({
    required this.id,
    required this.partyId,
    this.partyShopName,
    required this.salesmanId,
    this.salesmanName,
    required this.amount,
    required this.paymentMode,
    this.referenceNo,
    this.remarks,
    this.createdAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    String? shopName;
    if (json['parties'] != null && json['parties'] is Map) {
      shopName = json['parties']['shop_name'] as String?;
    }

    String? salesName;
    if (json['profiles'] != null && json['profiles'] is Map) {
      salesName = json['profiles']['name'] as String?;
    }

    return PaymentModel(
      id: json['id'].toString(),
      partyId: json['party_id'].toString(),
      partyShopName: shopName ?? json['party_shop_name'] as String?,
      salesmanId: json['salesman_id'].toString(),
      salesmanName: salesName ?? json['salesman_name'] as String?,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['payment_mode'] as String? ?? 'cash',
      referenceNo: json['reference_no'] as String?,
      remarks: json['remarks'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'party_id': partyId,
      'salesman_id': salesmanId,
      'amount': amount,
      'payment_mode': paymentMode,
      if (referenceNo != null && referenceNo!.isNotEmpty) 'reference_no': referenceNo,
      if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
    };
  }
}
