import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/party_model.dart';
import '../models/payment_model.dart';
import '../providers/auth_provider.dart';
import '../providers/payment_provider.dart';
import 'custom_button.dart';
import 'custom_textfield.dart';

class CollectPaymentDialog extends StatefulWidget {
  final PartyModel party;
  final VoidCallback? onPaymentRecorded;

  const CollectPaymentDialog({
    super.key,
    required this.party,
    this.onPaymentRecorded,
  });

  static Future<void> show(BuildContext context, PartyModel party, {VoidCallback? onPaymentRecorded}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CollectPaymentDialog(
        party: party,
        onPaymentRecorded: onPaymentRecorded,
      ),
    );
  }

  @override
  State<CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends State<CollectPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _refController = TextEditingController();
  final _remarksController = TextEditingController();

  String _selectedPaymentMode = 'cash'; // 'cash', 'upi', 'cheque', 'bank_transfer'

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final paymentProvider = Provider.of<PaymentProvider>(context, listen: false);

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid payment amount (> 0)'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final newPayment = PaymentModel(
      id: '',
      partyId: widget.party.id,
      partyShopName: widget.party.shopName,
      salesmanId: authProvider.currentProfile?.id ?? 'salesman-id',
      salesmanName: authProvider.currentProfile?.name ?? 'Salesman',
      amount: amount,
      paymentMode: _selectedPaymentMode,
      referenceNo: _refController.text.trim().isNotEmpty ? _refController.text.trim() : null,
      remarks: _remarksController.text.trim().isNotEmpty ? _remarksController.text.trim() : null,
      createdAt: DateTime.now(),
    );

    final success = await paymentProvider.recordPayment(newPayment);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment of ₹${amount.toStringAsFixed(2)} recorded successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      widget.onPaymentRecorded?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(paymentProvider.error ?? 'Failed to record payment'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentProvider = Provider.of<PaymentProvider>(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.payments_rounded, color: AppColors.success, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Collect Payment',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            widget.party.shopName,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Amount Input Field
              CustomTextField(
                label: 'Payment Amount (₹)',
                hint: 'Enter amount (e.g. 5000)',
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: Icons.currency_rupee_rounded,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter payment amount';
                  final numVal = double.tryParse(val.trim());
                  if (numVal == null || numVal <= 0) return 'Enter a valid amount > 0';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Payment Mode Selection Chips
              const Text(
                'Payment Mode',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _buildModeChip('cash', 'Cash 💵', Icons.money_rounded),
                  _buildModeChip('upi', 'UPI / GPay 📱', Icons.qr_code_2_rounded),
                  _buildModeChip('cheque', 'Cheque 📄', Icons.subtitles_rounded),
                  _buildModeChip('bank_transfer', 'Bank Transfer 🏦', Icons.account_balance_rounded),
                ],
              ),
              const SizedBox(height: 16),

              // Reference / Txn No
              if (_selectedPaymentMode != 'cash') ...[
                CustomTextField(
                  label: _selectedPaymentMode == 'cheque'
                      ? 'Cheque Number'
                      : 'UPI / Txn Reference No.',
                  hint: _selectedPaymentMode == 'cheque'
                      ? 'e.g. CHQ-482910'
                      : 'e.g. UPI-20491823901',
                  controller: _refController,
                  prefixIcon: Icons.receipt_long_rounded,
                ),
                const SizedBox(height: 16),
              ],

              // Remarks Input Field
              CustomTextField(
                label: 'Remarks / Notes (Optional)',
                hint: 'e.g. Part payment against Invoice #101',
                controller: _remarksController,
                prefixIcon: Icons.note_alt_outlined,
              ),
              const SizedBox(height: 24),

              // Submit Button
              CustomButton(
                text: 'Record Payment (₹)',
                isLoading: paymentProvider.isLoading,
                backgroundColor: AppColors.success,
                onPressed: _submitPayment,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip(String modeKey, String label, IconData icon) {
    final isSelected = _selectedPaymentMode == modeKey;

    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.background,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedPaymentMode = modeKey;
          });
        }
      },
    );
  }
}
