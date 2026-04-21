import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gear_up/core/theme/colors.dart';
import 'package:gear_up/core/localization/app_lang.dart';
import 'package:gear_up/features/marketplace/cubit/market_cubit.dart';
import 'package:gear_up/features/marketplace/cubit/market_state.dart';
import 'package:gear_up/features/auth/cubit/auth_cubit.dart';
import 'package:gear_up/features/marketplace/models/car_model.dart';
import 'package:gear_up/features/profile/screens/payments_screen.dart';
import 'package:gear_up/core/payment/payment_webview_screen.dart';
import 'package:gear_up/core/payment/paymob_manager.dart';
import 'package:gear_up/core/local_storage/cache_helper.dart';
import 'package:gear_up/features/auth/screens/login_screen.dart';

class StartSellingScreen extends StatefulWidget {
  final String initialItemType;
  final CarModel? itemToEdit;

  const StartSellingScreen({super.key, this.initialItemType = 'type_car', this.itemToEdit});

  @override
  State<StartSellingScreen> createState() => _StartSellingScreenState();
}

class _StartSellingScreenState extends State<StartSellingScreen> {
  late String _selectedItemTypeKey;
  String? _selectedTransmissionKey;
  String? _selectedConditionKey;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _mileageController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _hpController = TextEditingController();
  final TextEditingController _ccController = TextEditingController();
  final TextEditingController _torqueController = TextEditingController();
  final TextEditingController _luggageController = TextEditingController();

  final TextEditingController _sellerNameController = TextEditingController();
  final TextEditingController _sellerPhoneController = TextEditingController();
  final TextEditingController _sellerEmailController = TextEditingController();
  final TextEditingController _sellerLocationController = TextEditingController();

  bool _isCoreFieldsLocked = false;
  bool _isAiCar = false;

  @override
  void initState() {
    super.initState();
    _selectedItemTypeKey = widget.initialItemType;
    context.read<MarketCubit>().getPaymentData();

    final user = context.read<AuthCubit>().currentUser;
    bool isAdmin = user?.role == 'admin';

    if (widget.itemToEdit != null) {
      final car = widget.itemToEdit!;
      _isAiCar = car.sellerId.startsWith('ai_');
      _selectedItemTypeKey = car.itemType;
      _companyController.text = car.make;
      _modelController.text = car.model;
      _yearController.text = car.year;
      _priceController.text = car.price.toStringAsFixed(0);
      _descriptionController.text = car.description;
      _hpController.text = car.hp;
      _ccController.text = car.cc;
      _torqueController.text = car.torque;
      _luggageController.text = car.luggageCapacity;
      _mileageController.text = car.mileage;
      _sellerNameController.text = car.sellerName;
      _sellerPhoneController.text = car.sellerPhone;
      _sellerEmailController.text = car.sellerEmail;
      _sellerLocationController.text = car.sellerLocation;

      if (car.transmission != 'N/A' && car.transmission != 'Not Set') {
        _selectedTransmissionKey = car.transmission.toLowerCase();
      }
      if (car.condition == 'new_condition' || car.condition == 'used_condition') {
        _selectedConditionKey = car.condition;
      }

      if (!isAdmin && !_isAiCar) {
        try {
          if (DateTime.now().difference(DateTime.parse(car.createdAt)).inHours >= 24) {
            _isCoreFieldsLocked = true;
          }
        } catch (e) {}
      }

    } else {
      if (user != null) {
        _sellerNameController.text = user.name;
        _sellerPhoneController.text = user.phone;
        _sellerEmailController.text = user.email;
        _sellerLocationController.text = user.location;
      }
      _loadDraft();
    }
    _addDraftListeners();
  }

  void _loadDraft() {
    String? draftJson = CacheHelper.getData(key: 'selling_draft');
    if (draftJson != null) {
      try {
        Map<String, dynamic> draft = jsonDecode(draftJson);
        setState(() {
          _selectedItemTypeKey = draft['type'] ?? widget.initialItemType;
          _titleController.text = draft['title'] ?? '';
          _priceController.text = draft['price'] ?? '';
          _companyController.text = draft['company'] ?? '';
          _modelController.text = draft['model'] ?? '';
          _yearController.text = draft['year'] ?? '';
          _mileageController.text = draft['mileage'] ?? '';
          _descriptionController.text = draft['desc'] ?? '';
          _hpController.text = draft['hp'] ?? '';
          _ccController.text = draft['cc'] ?? '';
          _torqueController.text = draft['torque'] ?? '';
          _luggageController.text = draft['luggage'] ?? '';
          _selectedTransmissionKey = draft['transmission'];
          _selectedConditionKey = draft['condition'];
        });
      } catch (e) {}
    }
  }

  void _saveDraft() {
    if (widget.itemToEdit != null) return;

    Map<String, dynamic> draft = {
      'type': _selectedItemTypeKey, 'title': _titleController.text, 'price': _priceController.text,
      'company': _companyController.text, 'model': _modelController.text, 'year': _yearController.text,
      'mileage': _mileageController.text, 'desc': _descriptionController.text, 'hp': _hpController.text,
      'cc': _ccController.text, 'torque': _torqueController.text, 'luggage': _luggageController.text,
      'transmission': _selectedTransmissionKey, 'condition': _selectedConditionKey,
    };
    CacheHelper.saveData(key: 'selling_draft', value: jsonEncode(draft));
  }

  void _addDraftListeners() {
    _titleController.addListener(_saveDraft); _priceController.addListener(_saveDraft);
    _companyController.addListener(_saveDraft); _modelController.addListener(_saveDraft);
    _yearController.addListener(_saveDraft); _mileageController.addListener(_saveDraft);
    _descriptionController.addListener(_saveDraft); _hpController.addListener(_saveDraft);
    _ccController.addListener(_saveDraft); _torqueController.addListener(_saveDraft);
    _luggageController.addListener(_saveDraft);
  }

  @override
  void dispose() {
    _titleController.removeListener(_saveDraft); _priceController.removeListener(_saveDraft);
    _companyController.removeListener(_saveDraft); _modelController.removeListener(_saveDraft);
    _yearController.removeListener(_saveDraft); _mileageController.removeListener(_saveDraft);
    _descriptionController.removeListener(_saveDraft); _hpController.removeListener(_saveDraft);
    _ccController.removeListener(_saveDraft); _torqueController.removeListener(_saveDraft);
    _luggageController.removeListener(_saveDraft);
    _titleController.dispose(); _priceController.dispose(); _companyController.dispose();
    _modelController.dispose(); _yearController.dispose(); _mileageController.dispose();
    _descriptionController.dispose(); _hpController.dispose(); _ccController.dispose();
    _torqueController.dispose(); _luggageController.dispose(); _sellerNameController.dispose();
    _sellerPhoneController.dispose(); _sellerEmailController.dispose(); _sellerLocationController.dispose();
    super.dispose();
  }

  void _showGuestDialog(BuildContext context, String featureName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🔥 استبدال رسالة الزائر
    String msg = AppLang.tr(context, 'guest_restriction_msg') ?? "عفواً، لا يمكنك %s كزائر. قم بتسجيل الدخول لتستمتع بجميع مميزات GEAR UP! 🚗✨";
    msg = msg.replaceAll('%s', featureName);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: isDark ? 0 : 10,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.primary)),
              const SizedBox(height: 20),
              Text(AppLang.tr(context, 'login_required_title') ?? "تسجيل الدخول مطلوب", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Text(msg, textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14, height: 1.6)),
              const SizedBox(height: 32),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0), child: Text(AppLang.tr(context, 'login_btn') ?? "تسجيل الدخول", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(ctx), style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(AppLang.tr(context, 'cancel') ?? "إلغاء", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 15, fontWeight: FontWeight.bold)))),
            ],
          ),
        ),
      ),
    );
  }

  void _executePublishing() {
    final isEditing = widget.itemToEdit != null;
    if (isEditing) {
      bool isPromotedItem = context.read<MarketCubit>().promotedCarsList.any((c) => c.id == widget.itemToEdit!.id) ||
          context.read<MarketCubit>().promotedPartsList.any((p) => p.id == widget.itemToEdit!.id);

      context.read<MarketCubit>().updateCar(
        carId: widget.itemToEdit!.id, itemType: _selectedItemTypeKey, make: _companyController.text.trim(),
        model: _modelController.text.trim(), year: _yearController.text.trim().isEmpty ? 'Not Set' : _yearController.text.trim(),
        price: double.tryParse(_priceController.text.trim()) ?? 0.0, condition: _selectedConditionKey ?? 'Not Set',
        description: _descriptionController.text.trim(), hp: _hpController.text.trim(), cc: _ccController.text.trim(),
        torque: _torqueController.text.trim(), transmission: _selectedTransmissionKey ?? 'Not Set',
        luggageCapacity: _luggageController.text.trim(), mileage: _mileageController.text.trim(),
        sellerName: _sellerNameController.text.trim().isNotEmpty ? _sellerNameController.text.trim() : "Unknown Seller",
        sellerPhone: _sellerPhoneController.text.trim(), sellerLocation: _sellerLocationController.text.trim(),
        sellerEmail: _sellerEmailController.text.trim(),
        isPromoted: isPromotedItem,
      );
    } else {
      context.read<MarketCubit>().addCar(
        itemType: _selectedItemTypeKey, make: _companyController.text.trim(), model: _modelController.text.trim(),
        year: _yearController.text.trim().isEmpty ? 'Not Set' : _yearController.text.trim(), price: double.tryParse(_priceController.text.trim()) ?? 0.0,
        condition: _selectedConditionKey ?? 'Not Set', description: _descriptionController.text.trim(), hp: _hpController.text.trim(),
        cc: _ccController.text.trim(), torque: _torqueController.text.trim(), transmission: _selectedTransmissionKey ?? 'Not Set',
        luggageCapacity: _luggageController.text.trim(), mileage: _mileageController.text.trim(),
        sellerName: _sellerNameController.text.trim().isNotEmpty ? _sellerNameController.text.trim() : "Unknown Seller",
        sellerPhone: _sellerPhoneController.text.trim(), sellerLocation: _sellerLocationController.text.trim(),
        sellerEmail: _sellerEmailController.text.trim(),
      );
    }
  }

  void _showPaymentConfirmationSheet(bool isDark) {
    showModalBottomSheet(
      context: context, backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.payment, color: AppColors.primary, size: 32)),
                const SizedBox(height: 16),
                Text(AppLang.tr(context, 'publish_fee_title') ?? "رسوم نشر الإعلان", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                Text(AppLang.tr(context, 'publish_fee_desc') ?? "لضمان جدية الإعلانات، سيتم خصم مبلغ 50 جنيهاً مصرياً. يرجى اختيار طريقة الدفع في الخطوة التالية.", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14, height: 1.5)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(bottomSheetContext), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: isDark ? Colors.white24 : AppColors.borderLight), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), child: Text(AppLang.tr(context, 'cancel') ?? "إلغاء", style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(bottomSheetContext);
                          final marketCubit = context.read<MarketCubit>();

                          if (marketCubit.userPaymentMethods.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'add_payment_method_first') ?? 'الرجاء إضافة طريقة دفع أولاً لإتمام العملية'), backgroundColor: Colors.orange));
                            final selectedMethod = await Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentsScreen(isSelectionMode: true)));
                            if (selectedMethod != null && selectedMethod is Map<String, dynamic>) {
                              _executeActualPayment(selectedMethod);
                            }
                          } else {
                            _showPaymentMethodsSelectionSheet(isDark);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: Text(AppLang.tr(context, 'agree_to_continue') ?? "موافق للمتابعة", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPaymentMethodsSelectionSheet(bool isDark) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return BlocBuilder<MarketCubit, MarketState>(
          builder: (context, state) {
            final marketCubit = context.read<MarketCubit>();
            final methods = marketCubit.userPaymentMethods;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLang.tr(context, 'choose_payment_method') ?? "اختر طريقة الدفع", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 16),
                    if (methods.isEmpty) ...[
                      Center(child: Text(AppLang.tr(context, 'no_payment_methods') ?? "لا توجد طرق دفع مسجلة.", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 16),
                    ] else ...[
                      ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                        child: ListView.builder(
                          shrinkWrap: true, itemCount: methods.length,
                          itemBuilder: (context, index) {
                            final method = methods[index];
                            IconData icon = method['type'] == 'Card' ? Icons.credit_card : Icons.phone_android;
                            Color iconColor = method['title'].toString().contains('Vodafone') ? Colors.red : method['title'].toString().contains('Etisalat') ? Colors.green : method['title'].toString().contains('Orange') ? Colors.orange : method['type'] == 'Card' ? const Color(0xFF1976D2) : Colors.purple;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : const Color(0xFFF4F7FA), borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: iconColor)),
                                title: Text(method['title'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                subtitle: Text(method['subtitle'] ?? '', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 12)),
                                trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: () => _confirmDelete(context, () => marketCubit.deletePaymentMethod(method['id']))),
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _executeActualPayment(method);
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(sheetContext);
                          final selectedMethod = await Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentsScreen(isSelectionMode: true)));
                          if (selectedMethod != null && selectedMethod is Map<String, dynamic>) {
                            _executeActualPayment(selectedMethod);
                          }
                        },
                        icon: const Icon(Icons.add, color: AppColors.primary),
                        label: Text(AppLang.tr(context, 'add_new_payment_method') ?? "إضافة طريقة دفع جديدة", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: AppColors.primary, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeActualPayment(Map<String, dynamic> selectedMethod) async {
    final marketCubit = context.read<MarketCubit>();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'connecting_payment_gateway') ?? 'جاري الاتصال ببوابة الدفع، يرجى الانتظار...'), duration: const Duration(seconds: 3)));

    Map<String, dynamic> paymentResult;

    if (selectedMethod['type'] == 'Card') {
      paymentResult = await PaymobManager().getCardPaymentUrl(context, 50); // 🔥 تم تمرير السياق (context)
    } else {
      String walletNum = selectedMethod['subtitle'].toString().split('\n').last.trim();
      paymentResult = await PaymobManager().getWalletPaymentUrl(context, 50, walletNum); // 🔥 تم تمرير السياق
    }

    if (paymentResult['success'] == true) {
      String paymentUrl = paymentResult['url'];
      bool? paymentSuccess = await Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentWebViewScreen(paymentUrl: paymentUrl)));

      String defaultAdName = AppLang.tr(context, 'new_ad_default_name') ?? "إعلان جديد";
      String itemName = _companyController.text.trim().isNotEmpty ? "${_companyController.text.trim()} ${_modelController.text.trim()}" : defaultAdName;
      String publishFeesTxt = AppLang.tr(context, 'publish_fees') ?? "رسوم نشر";

      if (paymentSuccess == true) {
        await marketCubit.addTransactionRecord(title: "$itemName - $publishFeesTxt", amount: "-50 EGP", status: "Completed", isPositive: false);
        _executePublishing();
      } else {
        await marketCubit.addTransactionRecord(title: "$itemName - $publishFeesTxt", amount: "-50 EGP", status: "Failed", isPositive: false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'payment_failed_cancelled') ?? 'تم إلغاء أو فشل الدفع! وتم تسجيل العملية في السجل.'), backgroundColor: Colors.red));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(paymentResult['message']), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
    }
  }

  void _confirmDelete(BuildContext context, VoidCallback onConfirm) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(AppLang.tr(context, 'confirm_delete') ?? 'تأكيد الحذف', style: const TextStyle(fontWeight: FontWeight.bold)), content: Text(AppLang.tr(context, 'confirm_delete_payment_method') ?? 'هل أنت متأكد من أنك تريد مسح طريقة الدفع هذه؟'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLang.tr(context, 'cancel') ?? 'إلغاء')), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { Navigator.pop(ctx); onConfirm(); }, child: Text(AppLang.tr(context, 'delete') ?? 'حذف', style: const TextStyle(color: Colors.white)))]));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isCar = _selectedItemTypeKey == 'type_car';
    final bool isEditing = widget.itemToEdit != null;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

    // 🔥 الترجمة الذكية لعنوان الشاشة 🔥
    String screenTitle = isEditing
        ? (_isAiCar ? (AppLang.tr(context, 'edit_ai_car_data') ?? 'تعديل بيانات السيارة') : (AppLang.tr(context, 'edit_ad') ?? 'تعديل الإعلان'))
        : (AppLang.tr(context, 'start_selling_title') ?? 'Start Selling');

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Text(screenTitle, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        leading: GestureDetector(onTap: () { context.read<MarketCubit>().clearSelectedImages(); Navigator.pop(context); }, child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.3)), borderRadius: BorderRadius.circular(12), color: isDark ? const Color(0xFF161E27).withOpacity(0.8) : Colors.white.withOpacity(0.7)), child: Icon(Icons.arrow_back, size: 24, color: isDark ? Colors.white : AppColors.primary))),
        actions: [
          if (!isEditing)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              tooltip: AppLang.tr(context, 'clear_data_tooltip') ?? 'مسح البيانات',
              onPressed: () {
                CacheHelper.removeData(key: 'selling_draft');
                setState(() {
                  _titleController.clear(); _priceController.clear(); _companyController.clear();
                  _modelController.clear(); _yearController.clear(); _mileageController.clear();
                  _descriptionController.clear(); _hpController.clear(); _ccController.clear();
                  _torqueController.clear(); _luggageController.clear();
                  _selectedTransmissionKey = null; _selectedConditionKey = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'draft_cleared') ?? 'تم مسح المسودة والبدء من جديد')));
              },
            )
        ],
      ),
      body: BlocConsumer<MarketCubit, MarketState>(
        listener: (context, state) {
          if (state is AddCarSuccess) {
            if (!isEditing) CacheHelper.removeData(key: 'selling_draft');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? (AppLang.tr(context, 'edit_success') ?? 'تم التعديل بنجاح') : (AppLang.tr(context, 'publish_success') ?? 'تم النشر بنجاح')), backgroundColor: Colors.green));
            Navigator.pop(context);
          }
          else if (state is AddCarError) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error), backgroundColor: Colors.red)); }
        },
        builder: (context, state) {
          final List<File> selectedImages = context.read<MarketCubit>().selectedCarImages ?? [];
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(screenTitle, style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w900)), const SizedBox(height: 8),
                Text(isEditing ? (AppLang.tr(context, 'edit_data_hint') ?? 'عدل البيانات اللي محتاجها واضغط حفظ') : (AppLang.tr(context, 'choose_item_type') ?? 'Choose item type'), style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14)),

                if (isEditing && _isCoreFieldsLocked) Container(margin: const EdgeInsets.only(top: 16), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orangeAccent.withOpacity(0.5))), child: Row(children: [const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 20), const SizedBox(width: 10), Expanded(child: Text(AppLang.tr(context, 'core_fields_locked_warning') ?? 'مر 24 ساعة على نشر الإعلان. لا يمكن تغيير نوع أو ماركة أو موديل الإعلان لحماية المنصة.', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)))])), const SizedBox(height: 24),

                Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.02), blurRadius: 8, offset: const Offset(0, 4))]), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : AppColors.surfaceLight, shape: BoxShape.circle), child: Icon(isCar ? Icons.directions_car_outlined : _selectedItemTypeKey == 'type_part' ? Icons.build_outlined : Icons.add_circle_outline, color: _isCoreFieldsLocked ? Colors.grey : AppColors.primary, size: 20)), const SizedBox(width: 16), Text(AppLang.tr(context, _selectedItemTypeKey) ?? _selectedItemTypeKey, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)), const Spacer(), if (!_isCoreFieldsLocked) TextButton(onPressed: () => _showTypeSelectionSheet(isDark), style: TextButton.styleFrom(foregroundColor: AppColors.primary, backgroundColor: isDark ? const Color(0xFF1E2834) : AppColors.surfaceLight, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(AppLang.tr(context, 'change') ?? 'Change', style: const TextStyle(fontWeight: FontWeight.bold)))])), const SizedBox(height: 32),
                if (!isEditing) ...[Text(AppLang.tr(context, 'photos') ?? 'Photos', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 12), SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [GestureDetector(onTap: () { context.read<MarketCubit>().pickMultipleImages(); }, child: Container(width: 110, height: 110, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.5), style: BorderStyle.solid, width: 2)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 28), const SizedBox(height: 8), Text(AppLang.tr(context, 'add_photo') ?? 'Add Photo', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold))]))), ...selectedImages.map((image) { return Stack(children: [Container(width: 110, height: 110, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.black12), image: DecorationImage(image: FileImage(image), fit: BoxFit.cover))), Positioned(top: 4, right: 16, child: GestureDetector(onTap: () { context.read<MarketCubit>().removeImage(image); }, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16))))]); }).toList()])), const SizedBox(height: 12), Text(AppLang.tr(context, 'photo_limit_hint') ?? 'You can add up to 10 photos', style: const TextStyle(color: AppColors.textHint, fontSize: 12)), const SizedBox(height: 32)],
                _buildTextField(label: AppLang.tr(context, 'title') ?? 'Title', hint: AppLang.tr(context, 'title_hint') ?? 'e.g. BMW X5', controller: _titleController, isDark: isDark), _buildTextField(label: AppLang.tr(context, 'price_egp') ?? 'Price', hint: AppLang.tr(context, 'price_hint') ?? 'e.g. 500000', controller: _priceController, isNumber: true, isDark: isDark),
                Row(children: [Expanded(child: _buildTextField(label: isCar ? (AppLang.tr(context, 'company') ?? 'Make') : (AppLang.tr(context, 'part_name') ?? 'Part Name'), hint: isCar ? (AppLang.tr(context, 'company_hint') ?? 'BMW') : (AppLang.tr(context, 'part_hint') ?? 'Brake Pads'), controller: _companyController, isDark: isDark, readOnly: _isCoreFieldsLocked)), const SizedBox(width: 16), Expanded(child: _buildTextField(label: isCar ? (AppLang.tr(context, 'model') ?? 'Model') : (AppLang.tr(context, 'compatibility') ?? 'Compatibility'), hint: isCar ? (AppLang.tr(context, 'model_hint') ?? 'X5') : (AppLang.tr(context, 'compat_hint') ?? 'BMW X5'), controller: _modelController, isDark: isDark, readOnly: _isCoreFieldsLocked))]),
                if (isCar) ...[Row(children: [Expanded(child: _buildTextField(label: AppLang.tr(context, 'year') ?? 'Year', hint: AppLang.tr(context, 'year_optional_hint') ?? 'e.g. 2020', controller: _yearController, isNumber: true, isDark: isDark, readOnly: _isCoreFieldsLocked)), const SizedBox(width: 16), Expanded(child: _buildTextField(label: AppLang.tr(context, 'mileage') ?? 'Mileage', hint: AppLang.tr(context, 'mileage_optional_hint') ?? 'e.g. 50000', controller: _mileageController, isNumber: true, isDark: isDark))]), Row(children: [Expanded(child: _buildTextField(label: AppLang.tr(context, 'hp') ?? 'HP', hint: AppLang.tr(context, 'hp_optional_hint') ?? 'e.g. 250', controller: _hpController, isNumber: true, isDark: isDark)), const SizedBox(width: 16), Expanded(child: _buildTextField(label: AppLang.tr(context, 'cc') ?? 'CC', hint: AppLang.tr(context, 'cc_optional_hint') ?? 'e.g. 2000', controller: _ccController, isNumber: true, isDark: isDark))]), Row(children: [Expanded(child: _buildTextField(label: AppLang.tr(context, 'torque') ?? 'Torque', hint: AppLang.tr(context, 'torque_optional_hint') ?? 'e.g. 350', controller: _torqueController, isDark: isDark)), const SizedBox(width: 16), Expanded(child: _buildTextField(label: AppLang.tr(context, 'luggage_capacity') ?? 'Luggage', hint: AppLang.tr(context, 'luggage_optional_hint') ?? 'e.g. 500L', controller: _luggageController, isDark: isDark))]), _buildDropdownField(label: AppLang.tr(context, 'transmission') ?? 'Transmission', hint: AppLang.tr(context, 'transmission_hint') ?? 'Select', valueKey: _selectedTransmissionKey, itemKeys: ['automatic', 'manual'], isDark: isDark, onChanged: (val) { setState(() => _selectedTransmissionKey = val); _saveDraft(); })],
                _buildDropdownField(label: AppLang.tr(context, 'condition') ?? 'Condition', hint: AppLang.tr(context, 'condition_hint') ?? 'Select', valueKey: _selectedConditionKey, itemKeys: ['new_condition', 'used_condition'], isDark: isDark, onChanged: (val) { setState(() => _selectedConditionKey = val); _saveDraft(); }),
                _buildTextField(label: AppLang.tr(context, 'description') ?? 'Description', hint: AppLang.tr(context, 'desc_optional_hint') ?? 'Add details', controller: _descriptionController, maxLines: 4, isDark: isDark), const SizedBox(height: 24), Text(AppLang.tr(context, 'seller_info') ?? 'Seller Info', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 16), _buildTextField(label: AppLang.tr(context, 'seller_name') ?? 'Name', hint: AppLang.tr(context, 'enter_your_name') ?? "Enter your name", controller: _sellerNameController, isDark: isDark), _buildTextField(label: AppLang.tr(context, 'seller_phone') ?? 'Phone', hint: "01xxxxxxxxx", controller: _sellerPhoneController, isNumber: true, isDark: isDark), _buildTextField(label: "${AppLang.tr(context, 'seller_email') ?? 'Email'} (Optional)", hint: "example@mail.com", controller: _sellerEmailController, isDark: isDark), _buildTextField(label: "${AppLang.tr(context, 'seller_location') ?? 'Location'} (Optional)", hint: AppLang.tr(context, 'cairo_egypt_hint') ?? "Cairo, Egypt", controller: _sellerLocationController, isDark: isDark), const SizedBox(height: 32),
                GestureDetector(
                  onTap: state is AddCarLoading ? null : () {
                    if (CacheHelper.getData(key: 'uid') == null) {
                      _showGuestDialog(context, AppLang.tr(context, 'publish_ads_feature') ?? "نشر إعلانات");
                      return;
                    }
                    if (_priceController.text.isEmpty || _companyController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'price_make_required') ?? 'Required Fields Missing'), backgroundColor: Colors.red)); return; }
                    if (_sellerPhoneController.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'phone_required_error') ?? 'Phone Missing'), backgroundColor: Colors.red)); return; }
                    if (isEditing) { _executePublishing(); } else { _showPaymentConfirmationSheet(isDark); }
                  },
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 18), decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 6))]), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [state is AddCarLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(isEditing ? (AppLang.tr(context, 'save_changes') ?? 'حفظ التعديلات') : (AppLang.tr(context, 'publish_listing') ?? 'Publish'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5))])),
                ), const SizedBox(height: 60),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField({required String label, required String hint, required TextEditingController controller, required bool isDark, bool isNumber = false, int maxLines = 1, bool readOnly = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)), const SizedBox(height: 8), TextField(controller: controller, keyboardType: isNumber ? TextInputType.number : TextInputType.text, maxLines: maxLines, readOnly: readOnly, style: TextStyle(color: readOnly ? Colors.grey : (isDark ? Colors.white : Colors.black87), fontWeight: FontWeight.w500), decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14), filled: true, fillColor: readOnly ? (isDark ? const Color(0xFF121A22) : const Color(0xFFF0F0F0)) : (isDark ? const Color(0xFF1E2834) : Colors.white), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: readOnly ? (isDark ? Colors.white10 : Colors.black12) : AppColors.primary, width: readOnly ? 1 : 1.5))))]));
  }

  Widget _buildDropdownField({required String label, required String hint, required String? valueKey, required List<String> itemKeys, required bool isDark, required ValueChanged<String?> onChanged}) {
    return Padding(padding: const EdgeInsets.only(bottom: 20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)), const SizedBox(height: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: valueKey, hint: Text(hint, style: const TextStyle(color: AppColors.textHint, fontSize: 14)), isExpanded: true, dropdownColor: isDark ? const Color(0xFF1E2834) : Colors.white, icon: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white54 : Colors.black54), items: itemKeys.map((String key) { return DropdownMenuItem<String>(value: key, child: Text(AppLang.tr(context, key) ?? key, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500))); }).toList(), onChanged: onChanged)))]));
  }

  void _showTypeSelectionSheet(bool isDark) {
    showModalBottomSheet(context: context, backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))), builder: (context) { return SafeArea(child: Padding(padding: const EdgeInsets.symmetric(vertical: 24.0), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(AppLang.tr(context, 'select_item_type') ?? 'Select Item Type', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 24), _buildTypeOption('type_car', Icons.directions_car_outlined, isDark), _buildTypeOption('type_part', Icons.build_outlined, isDark), _buildTypeOption('type_accessory', Icons.add_circle_outline, isDark)]))); });
  }

  Widget _buildTypeOption(String key, IconData icon, bool isDark) {
    return ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : AppColors.surfaceLight, shape: BoxShape.circle), child: Icon(icon, color: AppColors.primary)), title: Text(AppLang.tr(context, key) ?? key, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)), onTap: () { setState(() => _selectedItemTypeKey = key); _saveDraft(); Navigator.pop(context); });
  }
}