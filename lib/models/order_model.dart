import 'order_item_model.dart';

class OrderModel {
  final String id;
  final String partyId;
  final String? partyShopName;
  final String? partyOwnerName;
  final String salesmanId;
  final String? salesmanName;
  final double totalAmount;
  final String status; // 'completed'
  final DateTime? createdAt;
  final List<OrderItemModel> items;

  OrderModel({
    required this.id,
    required this.partyId,
    this.partyShopName,
    this.partyOwnerName,
    required this.salesmanId,
    this.salesmanName,
    required this.totalAmount,
    required this.status,
    this.createdAt,
    this.items = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    String? shopName;
    String? ownerName;
    if (json['parties'] != null && json['parties'] is Map) {
      shopName = json['parties']['shop_name'] as String?;
      ownerName = json['parties']['owner_name'] as String?;
    }

    String? salesName;
    if (json['profiles'] != null && json['profiles'] is Map) {
      salesName = json['profiles']['name'] as String?;
    }

    List<OrderItemModel> parsedItems = [];
    if (json['order_items'] != null && json['order_items'] is List) {
      parsedItems = (json['order_items'] as List)
          .map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return OrderModel(
      id: json['id'].toString(),
      partyId: json['party_id'].toString(),
      partyShopName: shopName ?? json['party_shop_name'] as String?,
      partyOwnerName: ownerName ?? json['party_owner_name'] as String?,
      salesmanId: json['salesman_id'].toString(),
      salesmanName: salesName ?? json['salesman_name'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'completed',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'party_id': partyId,
      'salesman_id': salesmanId,
      'total_amount': totalAmount,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
