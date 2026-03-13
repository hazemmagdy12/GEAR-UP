import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../marketplace/cubit/market_state.dart';

class PaymentsScreen extends StatefulWidget {
  final bool isSelectionMode; // 🔥 وضع الاختيار لو جي من شاشة البيع 🔥

  const PaymentsScreen({super.key, this.isSelectionMode = false});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  int _selectedTab = 0;
  String? _addingMethodType;
  String _dynamicWalletName = ""; // هيتم تعيينها في initState أو build

  final TextEditingController _walletPhoneController = TextEditingController();
  final TextEditingController _walletNameController = TextEditingController();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _cardNameController = TextEditingController();
  final TextEditingController _cardExpiryController = TextEditingController();
  final TextEditingController _cardCvvController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<MarketCubit>().getPaymentData();

    _walletPhoneController.addListener(() {
      String text = _walletPhoneController.text;
      String newName = AppLang.tr(context, 'add_ewallet_title') ?? "إضافة محفظة إلكترونية";

      if (text.startsWith('010')) newName = "Vodafone Cash";
      else if (text.startsWith('011')) newName = "Etisalat Cash";
      else if (text.startsWith('012')) newName = "Orange Cash";
      else if (text.startsWith('015')) newName = "WE Pay";

      if (_dynamicWalletName != newName) {
        setState(() => _dynamicWalletName = newName);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dynamicWalletName.isEmpty) {
      _dynamicWalletName = AppLang.tr(context, 'add_ewallet_title') ?? "إضافة محفظة إلكترونية";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: widget.isSelectionMode
            ? Text(AppLang.tr(context, 'choose_payment_method_title') ?? "اختر طريقة الدفع", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18))
            : null,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.3)), borderRadius: BorderRadius.circular(12), color: isDark ? const Color(0xFF161E27).withOpacity(0.8) : Colors.white.withOpacity(0.7)),
            child: Icon(Icons.arrow_back, size: 24, color: isDark ? Colors.white : AppColors.primary),
          ),
        ),
      ),
      body: BlocBuilder<MarketCubit, MarketState>(
          builder: (context, state) {
            final cubit = context.read<MarketCubit>();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.isSelectionMode) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLang.tr(context, 'payments') ?? 'Payments', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 8),
                        Text(AppLang.tr(context, 'manage_payment_methods') ?? 'Manage your payment methods and history.', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                      child: Row(
                        children: [
                          Expanded(child: GestureDetector(onTap: () => setState(() { _selectedTab = 0; _addingMethodType = null; }), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: _selectedTab == 0 ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(AppLang.tr(context, 'payment_methods_tab') ?? 'طرق الدفع', style: TextStyle(color: _selectedTab == 0 ? Colors.white : (isDark ? Colors.white70 : AppColors.textSecondary), fontWeight: FontWeight.bold)))))),
                          Expanded(child: GestureDetector(onTap: () => setState(() { _selectedTab = 1; _addingMethodType = null; }), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: _selectedTab == 1 ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(AppLang.tr(context, 'history_tab') ?? 'السجل', style: TextStyle(color: _selectedTab == 1 ? Colors.white : (isDark ? Colors.white70 : AppColors.textSecondary), fontWeight: FontWeight.bold)))))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                Expanded(
                  child: _selectedTab == 0 ? _buildPaymentMethodsView(isDark, cubit.userPaymentMethods, cubit) : _buildHistoryView(isDark, cubit.userTransactions, cubit),
                ),
              ],
            );
          }
      ),
    );
  }

  Widget _buildPaymentMethodsView(bool isDark, List<Map<String, dynamic>> methods, MarketCubit cubit) {
    if (cubit.isLoadingPayments) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      children: [
        if (widget.isSelectionMode && methods.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(AppLang.tr(context, 'click_to_pay_hint') ?? "اضغط على المحفظة أو الكارت لإتمام الدفع:", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
          ),

        if (methods.isEmpty && _addingMethodType == null) ...[
          const SizedBox(height: 40),
          Center(child: Column(children: [Icon(Icons.credit_card_off_rounded, size: 60, color: isDark ? Colors.white24 : Colors.black12), const SizedBox(height: 16), Text(AppLang.tr(context, 'no_saved_payment_methods') ?? "لا توجد طرق دفع محفوظة", style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold))])),
          const SizedBox(height: 40),
        ],

        if (methods.isNotEmpty)
          ...methods.map((method) {
            IconData icon = method['type'] == 'Card' ? Icons.credit_card : Icons.phone_android;
            Color iconColor = method['title'].toString().contains('Vodafone') ? Colors.red :
            method['title'].toString().contains('Etisalat') ? Colors.green :
            method['title'].toString().contains('Orange') ? Colors.orange :
            method['type'] == 'Card' ? const Color(0xFF1976D2) : Colors.purple;

            return GestureDetector(
              onTap: () {
                if (widget.isSelectionMode) {
                  Navigator.pop(context, method);
                }
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: widget.isSelectionMode ? AppColors.primary.withOpacity(0.5) : (isDark ? Colors.white10 : Colors.black12)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Text(method['title'] ?? '', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87))]),
                          const SizedBox(height: 6),
                          Text(method['subtitle'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13, height: 1.4)),
                        ],
                      ),
                    ),
                    if (!widget.isSelectionMode)
                      IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmDelete(context, () => cubit.deletePaymentMethod(method['id']))),
                    if (widget.isSelectionMode)
                      const Icon(Icons.arrow_forward_ios, color: AppColors.primary, size: 16)
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 16),

        if (_addingMethodType == null)
          GestureDetector(
            onTap: () => _showAddPaymentOptions(isDark),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 24), const SizedBox(width: 12), Text(AppLang.tr(context, 'add_payment_method_btn') ?? 'Add New Method', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16))]),
            ),
          )
        else
          _buildAddMethodForm(isDark),

        const SizedBox(height: 40),
      ],
    );
  }

  void _showAddPaymentOptions(bool isDark) {
    showModalBottomSheet(
      context: context, backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLang.tr(context, 'select_payment_type') ?? "اختر نوع الدفع", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 24),
                _buildTypeOption(AppLang.tr(context, 'bank_card_option') ?? "بطاقة بنكية (Credit/Debit)", Icons.credit_card, "Card", isDark),
                _buildTypeOption(AppLang.tr(context, 'mobile_wallet_option') ?? "موبايل واليت (فودافون، اتصالات، اورانج، وي)", Icons.phone_android, "Wallet", isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  ListTile _buildTypeOption(String title, IconData icon, String type, bool isDark) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: AppColors.primary, size: 20)),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontSize: 15)),
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _addingMethodType = type; _dynamicWalletName = AppLang.tr(context, 'add_ewallet_title') ?? "إضافة محفظة إلكترونية";
          _walletPhoneController.clear(); _walletNameController.clear(); _cardNumberController.clear(); _cardNameController.clear(); _cardExpiryController.clear(); _cardCvvController.clear();
        });
      },
    );
  }

  Widget _buildAddMethodForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 15, offset: const Offset(0, 6))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_addingMethodType == 'Card' ? (AppLang.tr(context, 'add_new_card_title') ?? 'إضافة بطاقة جديدة') : _dynamicWalletName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 24),

          if (_addingMethodType == 'Card') ...[
            _buildTextField(label: AppLang.tr(context, 'card_number') ?? 'رقم البطاقة', hint: "16 رقم", controller: _cardNumberController, isNumber: true, maxLength: 16, isDark: isDark),
            _buildTextField(label: AppLang.tr(context, 'name_on_card') ?? 'الاسم على البطاقة', hint: AppLang.tr(context, 'full_name_hint') ?? "الاسم بالكامل", controller: _cardNameController, isDark: isDark),
            Row(children: [Expanded(child: _buildTextField(label: AppLang.tr(context, 'expiry_date') ?? 'تاريخ الانتهاء', hint: "MM/YY", controller: _cardExpiryController, maxLength: 5, isDark: isDark)), const SizedBox(width: 16), Expanded(child: _buildTextField(label: AppLang.tr(context, 'cvv_label') ?? 'CVV', hint: AppLang.tr(context, 'three_digits_hint') ?? "3 أرقام", controller: _cardCvvController, isNumber: true, maxLength: 3, isDark: isDark))]),
          ] else ...[
            _buildTextField(label: AppLang.tr(context, 'wallet_number') ?? 'رقم المحفظة', hint: AppLang.tr(context, 'english_numbers_hint') ?? "11 رقم إنجليزي (010, 011, 012, 015)", controller: _walletPhoneController, isNumber: true, maxLength: 11, isDark: isDark),
            _buildTextField(label: AppLang.tr(context, 'name_label') ?? 'الاسم', hint: AppLang.tr(context, 'name_label') ?? "الاسم", controller: _walletNameController, isDark: isDark),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _addingMethodType = null), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), side: BorderSide(color: isDark ? Colors.white24 : AppColors.borderLight)), child: Text(AppLang.tr(context, 'cancel_btn') ?? 'إلغاء', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)))),
              const SizedBox(width: 12),
              Expanded(
                  child: ElevatedButton(
                      onPressed: () async {
                        if (_addingMethodType == 'Wallet') {
                          if (_walletPhoneController.text.length != 11 || !_walletPhoneController.text.startsWith('01')) return;
                          await context.read<MarketCubit>().addPaymentMethod(type: 'Wallet', phoneNumber: _walletPhoneController.text, name: _walletNameController.text, walletName: _dynamicWalletName);
                        } else {
                          await context.read<MarketCubit>().addPaymentMethod(type: 'Card', cardNumber: _cardNumberController.text, cardholderName: _cardNameController.text, expiryDate: _cardExpiryController.text);
                        }
                        setState(() => _addingMethodType = null);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                      child: Text(AppLang.tr(context, 'save_btn') ?? 'حفظ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                  )
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({required String label, required String hint, required TextEditingController controller, required bool isDark, bool isNumber = false, int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 8),
          TextField(
              controller: controller, keyboardType: isNumber ? TextInputType.number : TextInputType.text, maxLength: maxLength,
              inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint, hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13), filled: true, fillColor: isDark ? const Color(0xFF1E2834) : Colors.white, counterText: "",
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
              )
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryView(bool isDark, List<Map<String, dynamic>> transactions, MarketCubit cubit) {
    if (cubit.isLoadingPayments) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      children: [
        if (transactions.isEmpty) ...[
          const SizedBox(height: 60),
          Center(child: Column(children: [Icon(Icons.receipt_long_outlined, size: 60, color: isDark ? Colors.white24 : Colors.black12), const SizedBox(height: 16), Text(AppLang.tr(context, 'no_previous_transactions') ?? "لا توجد عمليات سابقة", style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold))])),
        ],
        if (transactions.isNotEmpty)
          ...transactions.map((t) => _buildTransactionCard(id: t['id'] ?? '', title: t['title'] ?? '', date: t['date'] ?? '', amount: t['amount'] ?? '', status: t['status'] ?? '', isPositive: t['isPositive'] ?? false, isDark: isDark, cubit: cubit)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildTransactionCard({required String id, required String title, required String date, required String amount, required String status, required bool isPositive, required bool isDark, required MarketCubit cubit}) {
    bool isCompleted = status.toLowerCase() == 'completed'; bool isFailed = status.toLowerCase() == 'failed';
    Color statusColor = isCompleted ? const Color(0xFF4CAF50) : (isFailed ? Colors.red : const Color(0xFFF57C00));
    IconData statusIcon = isCompleted ? Icons.check_circle_rounded : (isFailed ? Icons.cancel : Icons.schedule_rounded);

    return Container(
      margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(statusIcon, color: statusColor, size: 14), const SizedBox(width: 6), Text(status == 'Failed' ? (AppLang.tr(context, 'status_failed') ?? 'فشلت') : (status == 'Completed' ? (AppLang.tr(context, 'status_completed') ?? 'ناجحة') : (AppLang.tr(context, 'status_pending') ?? status)), style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w900))])),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(date, style: TextStyle(color: isDark ? Colors.white54 : AppColors.textHint, fontSize: 13, fontWeight: FontWeight.w500)),
              GestureDetector(onTap: () => _confirmDelete(context, () => cubit.deleteTransactionRecord(id)), child: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20))
            ],
          ),
          const SizedBox(height: 8),
          Text(amount, style: TextStyle(color: isPositive ? const Color(0xFF4CAF50) : AppColors.primary, fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(title: Text(AppLang.tr(context, 'confirm_delete_title') ?? 'تأكيد الحذف', style: const TextStyle(fontWeight: FontWeight.bold)), content: Text(AppLang.tr(context, 'confirm_delete_msg') ?? 'هل أنت متأكد من أنك تريد الحذف؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr(context, 'cancel_btn') ?? 'إلغاء')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { Navigator.pop(ctx); onConfirm(); }, child: Text(AppLang.tr(context, 'delete_btn') ?? 'حذف', style: const TextStyle(color: Colors.white)))]),
    );
  }
}