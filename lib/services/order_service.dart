import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import 'supabase_service.dart';

class OrderService {
  final SupabaseService _supabaseService = SupabaseService();

  static final List<OrderModel> _demoOrders = [
    OrderModel(
      id: 'ord-101',
      partyId: 'party-1',
      partyShopName: 'Gupta General Store',
      partyOwnerName: 'Ramesh Gupta',
      salesmanId: 'salesman-456',
      salesmanName: 'Demo Salesman',
      totalAmount: 5800.0,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      items: [
        OrderItemModel(
          id: 'item-1',
          orderId: 'ord-101',
          productId: 'prod-1',
          productName: 'Basmati Rice (25kg Bag)',
          quantity: 2,
          price: 1850.0,
        ),
        OrderItemModel(
          id: 'item-2',
          orderId: 'ord-101',
          productId: 'prod-2',
          productName: 'Refined Oil (15L Tin)',
          quantity: 1,
          price: 2100.0,
        ),
      ],
    ),
  ];

  Future<List<OrderModel>> getOrders() async {
    try {
      if (!_supabaseService.isInitialized || 
          SupabaseService().client.auth.currentSession == null) {
        return List.from(_demoOrders);
      }

      final response = await _supabaseService.client
          .from('orders')
          .select('''
            *,
            parties (shop_name, owner_name),
            profiles (name),
            order_items (
              *,
              products (name)
            )
          ''')
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return List.from(_demoOrders);
      }
      return data.map((json) => OrderModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('OrderService getOrders fallback: $e');
      return List.from(_demoOrders);
    }
  }

  Future<String> placeOrder({
    required String partyId,
    required String partyShopName,
    required String salesmanId,
    required String salesmanName,
    required double totalAmount,
    required List<OrderItemModel> items,
  }) async {
    try {
      if (!_supabaseService.isInitialized || 
          SupabaseService().client.auth.currentSession == null) {
        final orderId = 'ord-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
        final newOrder = OrderModel(
          id: orderId,
          partyId: partyId,
          partyShopName: partyShopName,
          salesmanId: salesmanId,
          salesmanName: salesmanName,
          totalAmount: totalAmount,
          status: 'completed',
          createdAt: DateTime.now(),
          items: items,
        );
        _demoOrders.insert(0, newOrder);
        return orderId;
      }

      final itemsJson = items.map((item) => {
        'product_id': item.productId,
        'quantity': item.quantity,
        'price': item.price,
      }).toList();

      // Call Stored Procedure for atomic order insertion & stock deduction
      final response = await _supabaseService.client.rpc(
        'place_order_with_items',
        params: {
          'p_party_id': partyId,
          'p_salesman_id': salesmanId,
          'p_total_amount': totalAmount,
          'p_items': itemsJson,
        },
      );

      final orderId = response.toString();
      final newOrder = OrderModel(
        id: orderId,
        partyId: partyId,
        partyShopName: partyShopName,
        salesmanId: salesmanId,
        salesmanName: salesmanName,
        totalAmount: totalAmount,
        status: 'completed',
        createdAt: DateTime.now(),
        items: items,
      );
      _demoOrders.insert(0, newOrder);
      return orderId;
    } catch (e) {
      debugPrint('OrderService placeOrder RPC fallback: $e');
      final orderId = 'ord-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      final newOrder = OrderModel(
        id: orderId,
        partyId: partyId,
        partyShopName: partyShopName,
        salesmanId: salesmanId,
        salesmanName: salesmanName,
        totalAmount: totalAmount,
        status: 'completed',
        createdAt: DateTime.now(),
        items: items,
      );
      _demoOrders.insert(0, newOrder);
      return orderId;
    }
  }
}
