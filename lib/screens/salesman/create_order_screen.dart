import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/party_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/stock_badge.dart';
import '../../widgets/shop_verification_card.dart';
import '../parties/parties_screen.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ProductProvider>(context, listen: false).fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectParty(BuildContext context) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final selected = await Navigator.of(context).push<PartyModel>(
      MaterialPageRoute(builder: (_) => const PartiesScreen(isSelectionMode: true)),
    );
    if (selected != null) {
      cart.selectParty(selected);
    }
  }

  void _editItemRemark(BuildContext context, CartProvider cart, String productId, String productName) {
    final existingItem = cart.cartItems.firstWhere((i) => i.productId == productId);
    final remarkController = TextEditingController(text: existingItem.remark ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.note_alt_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Remark for $productName',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: TextField(
          controller: remarkController,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter manual remark/note (e.g. Special packing, Scheme item, etc.)...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              cart.updateRemark(productId, remarkController.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save Remark'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndPlaceOrder(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final cart = Provider.of<CartProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    if (cart.selectedParty == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please select a party first before confirming order'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (cart.cartItems.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product to the order'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shopping_bag_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Confirm Order'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Party: ${cart.selectedParty!.shopName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Total Items: ${cart.itemCount}'),
            const SizedBox(height: 4),
            Text('Total Amount: ₹${cart.totalAmount.toStringAsFixed(2)}', 
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
            const SizedBox(height: 12),
            const Text(
              'Stock will be automatically deducted upon confirmation.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm & Place Order'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final salesman = auth.currentProfile;
    final salesmanId = salesman?.id ?? 'salesman-id';
    final salesmanName = salesman?.name ?? 'Salesman';

    final orderId = await orderProvider.placeOrder(
      partyId: cart.selectedParty!.id,
      partyShopName: cart.selectedParty!.shopName,
      salesmanId: salesmanId,
      salesmanName: salesmanName,
      totalAmount: cart.totalAmount,
      items: cart.cartItems,
    );

    if (!mounted) return;

    if (orderId != null) {
      // Deduct stock locally in ProductProvider for instant UI sync
      for (var item in cart.cartItems) {
        productProvider.deductStockLocally(item.productId, item.quantity);
      }

      final partyName = cart.selectedParty!.shopName;
      if (!mounted) return;
      await showDialog(
        // ignore: use_build_context_synchronously
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Order Placed Successfully!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Order #$orderId for $partyName has been recorded.', textAlign: TextAlign.center),
              const SizedBox(height: 6),
              const Text(
                'Product stock has been automatically updated.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    navigator.pop(); // Return to dashboard
                  },
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(orderProvider.errorMessage ?? 'Failed to place order'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context);

    final products = productProvider.filteredProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Wholesale Order'),
      ),
      body: Column(
        children: [
          // Step 1: Select Party Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withValues(alpha: 0.06),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '1. Select Party / Shop',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cart.selectedParty != null
                            ? cart.selectedParty!.shopName
                            : 'No Party Selected',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: cart.selectedParty != null ? AppColors.primaryDark : AppColors.error,
                        ),
                      ),
                      if (cart.selectedParty != null)
                        Text(
                          'Owner: ${cart.selectedParty!.ownerName} (${cart.selectedParty!.mobile})',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: cart.selectedParty != null ? AppColors.surface : AppColors.primary,
                    foregroundColor: cart.selectedParty != null ? AppColors.primary : Colors.white,
                    elevation: 1,
                  ),
                  icon: Icon(cart.selectedParty != null ? Icons.edit_rounded : Icons.add_rounded, size: 18),
                  label: Text(cart.selectedParty != null ? 'Change' : 'Select Party'),
                  onPressed: () => _selectParty(context),
                ),
              ],
            ),
          ),

          // Shop Location Verification Component
          if (cart.selectedParty != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ShopVerificationCard(party: cart.selectedParty!),
            ),

          // Step 2: Search Products Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => productProvider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: 'Search products to add...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          productProvider.setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Step 3: Product List & Quantity Controls
          Expanded(
            child: productProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? const Center(child: Text('No products available'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final currentQty = cart.getQuantity(product.id);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '₹${product.price.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            StockBadge(stock: product.stock),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Quantity Counter Controls & Remark Option
                                  if (product.stock <= 0)
                                    const Text(
                                      'Out of Stock',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    )
                                  else if (currentQty == 0)
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      ),
                                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                                      label: const Text('Add'),
                                      onPressed: () => cart.addProduct(product),
                                    )
                                  else
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.inputFill,
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: AppColors.cardBorder),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.remove_rounded, size: 18),
                                                color: AppColors.primary,
                                                onPressed: () => cart.updateQuantity(
                                                  product.id,
                                                  currentQty - 1,
                                                  product.stock,
                                                ),
                                              ),
                                              Text(
                                                '$currentQty',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.add_rounded, size: 18),
                                                color: currentQty < product.stock
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary,
                                                onPressed: currentQty < product.stock
                                                    ? () => cart.updateQuantity(
                                                          product.id,
                                                          currentQty + 1,
                                                          product.stock,
                                                        )
                                                    : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: () => _editItemRemark(context, cart, product.id, product.name),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.note_alt_outlined,
                                                size: 14,
                                                color: cart.cartItems.firstWhere((i) => i.productId == product.id).remark?.isNotEmpty == true
                                                    ? AppColors.primary
                                                    : AppColors.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                cart.cartItems.firstWhere((i) => i.productId == product.id).remark?.isNotEmpty == true
                                                    ? 'Remark Added'
                                                    : '+ Add Remark',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: cart.cartItems.firstWhere((i) => i.productId == product.id).remark?.isNotEmpty == true
                                                      ? AppColors.primary
                                                      : AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Step 4: Bottom Order Summary & Confirm Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${cart.itemCount} Items Selected',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Total: ₹${cart.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          backgroundColor: AppColors.primary,
                        ),
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text('Confirm Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: (cart.selectedParty != null && cart.cartItems.isNotEmpty && !orderProvider.isLoading)
                            ? () => _confirmAndPlaceOrder(context)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
