import 'package:flutter/material.dart';
import '../models/order_model.dart';
import '../models/order_item_model.dart';
import '../services/order_service.dart';

class OrderProvider extends ChangeNotifier {
  final OrderService _orderService = OrderService();

  List<OrderModel> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  int get totalOrdersCount => _orders.length;

  Future<void> fetchOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _orderService.getOrders();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> placeOrder({
    required String partyId,
    required String partyShopName,
    required String salesmanId,
    required String salesmanName,
    required double totalAmount,
    required List<OrderItemModel> items,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final orderId = await _orderService.placeOrder(
        partyId: partyId,
        partyShopName: partyShopName,
        salesmanId: salesmanId,
        salesmanName: salesmanName,
        totalAmount: totalAmount,
        items: items,
      );
      await fetchOrders(); // refresh list
      _isLoading = false;
      notifyListeners();
      return orderId;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
}
