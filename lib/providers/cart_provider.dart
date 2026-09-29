import 'package:flutter/material.dart';
import '../models/party_model.dart';
import '../models/product_model.dart';
import '../models/order_item_model.dart';

class CartProvider extends ChangeNotifier {
  PartyModel? _selectedParty;
  final Map<String, OrderItemModel> _items = {};

  PartyModel? get selectedParty => _selectedParty;
  List<OrderItemModel> get cartItems => _items.values.toList();
  int get itemCount => _items.length;

  double get totalAmount {
    double total = 0.0;
    _items.forEach((key, item) {
      total += item.totalPrice;
    });
    return total;
  }

  void selectParty(PartyModel? party) {
    _selectedParty = party;
    notifyListeners();
  }

  void addProduct(ProductModel product, {int quantity = 1, String? remark}) {
    if (_items.containsKey(product.id)) {
      final existing = _items[product.id]!;
      final newQty = existing.quantity + quantity;
      if (newQty <= product.stock) {
        _items[product.id] = OrderItemModel(
          productId: product.id,
          productName: product.name,
          quantity: newQty,
          price: product.price,
          remark: remark ?? existing.remark,
        );
      }
    } else {
      if (quantity <= product.stock && product.stock > 0) {
        _items[product.id] = OrderItemModel(
          productId: product.id,
          productName: product.name,
          quantity: quantity,
          price: product.price,
          remark: remark,
        );
      }
    }
    notifyListeners();
  }

  void updateQuantity(String productId, int newQuantity, int availableStock) {
    if (!_items.containsKey(productId)) return;

    if (newQuantity <= 0) {
      _items.remove(productId);
    } else if (newQuantity <= availableStock) {
      final existing = _items[productId]!;
      _items[productId] = OrderItemModel(
        productId: productId,
        productName: existing.productName,
        quantity: newQuantity,
        price: existing.price,
        remark: existing.remark,
      );
    }
    notifyListeners();
  }

  void updateRemark(String productId, String remark) {
    if (!_items.containsKey(productId)) return;
    final existing = _items[productId]!;
    _items[productId] = OrderItemModel(
      productId: productId,
      productName: existing.productName,
      quantity: existing.quantity,
      price: existing.price,
      hsnCode: existing.hsnCode,
      pcsPerBox: existing.pcsPerBox,
      unit: existing.unit,
      discountPercent: existing.discountPercent,
      gstRate: existing.gstRate,
      remark: remark.trim().isEmpty ? null : remark.trim(),
    );
    notifyListeners();
  }

  void removeItem(String productId) {
    _items.remove(productId);
    notifyListeners();
  }

  int getQuantity(String productId) {
    return _items[productId]?.quantity ?? 0;
  }

  void clearCart() {
    _selectedParty = null;
    _items.clear();
    notifyListeners();
  }
}
