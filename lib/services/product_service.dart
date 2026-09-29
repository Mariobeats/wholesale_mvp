import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import 'supabase_service.dart';

class ProductService {
  final SupabaseService _supabaseService = SupabaseService();

  // In-memory mock list for instant testing / demo mode
  static final List<ProductModel> _demoProducts = [
    ProductModel(
      id: 'prod-1',
      name: 'Basmati Rice (25kg Bag)',
      price: 1850.0,
      stock: 45,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
    ProductModel(
      id: 'prod-2',
      name: 'Refined Oil (15L Tin)',
      price: 2100.0,
      stock: 20,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    ProductModel(
      id: 'prod-3',
      name: 'Sugar Superfine (50kg Bag)',
      price: 2350.0,
      stock: 8,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    ProductModel(
      id: 'prod-4',
      name: 'Wheat Atta (10kg Bag)',
      price: 420.0,
      stock: 0, // Out of stock
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    ProductModel(
      id: 'prod-5',
      name: 'Toor Dal Premium (30kg)',
      price: 3600.0,
      stock: 30,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  Future<List<ProductModel>> getProducts() async {
    try {
      if (!_supabaseService.isInitialized || 
          SupabaseService().client.auth.currentSession == null) {
        return List.from(_demoProducts);
      }

      final response = await _supabaseService.client
          .from('products')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return List.from(_demoProducts);
      }
      return data.map((json) => ProductModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('ProductService getProducts fallback: $e');
      return List.from(_demoProducts);
    }
  }

  Future<ProductModel> addProduct(ProductModel product) async {
    try {
      if (!_supabaseService.isInitialized || 
          SupabaseService().client.auth.currentSession == null) {
        final newProd = product.copyWith(
          id: 'prod-${DateTime.now().millisecondsSinceEpoch}',
          createdAt: DateTime.now(),
        );
        _demoProducts.insert(0, newProd);
        return newProd;
      }

      final response = await _supabaseService.client
          .from('products')
          .insert({
            'name': product.name,
            'price': product.price,
            'stock': product.stock,
          })
          .select()
          .single();

      return ProductModel.fromJson(response);
    } catch (e) {
      debugPrint('ProductService addProduct fallback: $e');
      final newProd = product.copyWith(
        id: 'prod-${DateTime.now().millisecondsSinceEpoch}',
        createdAt: DateTime.now(),
      );
      _demoProducts.insert(0, newProd);
      return newProd;
    }
  }

  Future<ProductModel> updateProduct(ProductModel product) async {
    try {
      if (!_supabaseService.isInitialized || 
          SupabaseService().client.auth.currentSession == null) {
        final index = _demoProducts.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          _demoProducts[index] = product;
        }
        return product;
      }

      final response = await _supabaseService.client
          .from('products')
          .update({
            'name': product.name,
            'price': product.price,
            'stock': product.stock,
          })
          .eq('id', product.id)
          .select()
          .single();

      return ProductModel.fromJson(response);
    } catch (e) {
      debugPrint('ProductService updateProduct fallback: $e');
      final index = _demoProducts.indexWhere((p) => p.id == product.id);
      if (index != -1) {
        _demoProducts[index] = product;
      }
      return product;
    }
  }

  Future<void> deleteProduct(String id) async {
    try {
      if (!_supabaseService.isInitialized || 
          SupabaseService().client.auth.currentSession == null) {
        _demoProducts.removeWhere((p) => p.id == id);
        return;
      }

      await _supabaseService.client.from('products').delete().eq('id', id);
    } catch (e) {
      debugPrint('ProductService deleteProduct fallback: $e');
      _demoProducts.removeWhere((p) => p.id == id);
    }
  }
}
