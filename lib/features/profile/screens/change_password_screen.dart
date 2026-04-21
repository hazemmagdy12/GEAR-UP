import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../home/widgets/ai_chat_bottom_sheet.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  // 🔥 متغيرات جديدة للتحكم في إظهار وإخفاء الباسوورد
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // 1. التحقق من الحقول الفارغة
    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar(AppLang.tr(context, 'all_fields_required') ?? 'جميع الحقول مطلوبة', Colors.red);
      return;
    }

    // 2. التحقق من التطابق
    if (newPassword != confirmPassword) {
      _showSnackBar(AppLang.tr(context, 'new_password_mismatch') ?? 'كلمة المرور الجديدة غير متطابقة', Colors.red);
      return;
    }

    // 3. التحقق من قوة الباسوورد
    final passwordRegex = RegExp(r'^(?=.*[a-zA-Z])(?=.*\d).+$');
    if (!passwordRegex.hasMatch(newPassword) || newPassword.length < 8) {
      _showSnackBar(AppLang.tr(context, 'password_requirements_msg') ?? 'كلمة المرور يجب أن تحتوي على حروف وأرقام، ولا تقل عن 8 خانات', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {

        // التحقق من أن المستخدم مسجل بالإيميل والباسوورد وليس جوجل
        final isPasswordProvider = user.providerData.any((userInfo) => userInfo.providerId == 'password');

        if (!isPasswordProvider) {
          _showSnackBar(AppLang.tr(context, 'social_login_password_error') ?? 'لا يمكن تغيير كلمة المرور لحسابات جوجل أو فيسبوك', Colors.orange);
          setState(() => _isLoading = false);
          return;
        }

        // إعادة المصادقة
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);

        // تحديث الباسوورد
        await user.updatePassword(newPassword);

        if (mounted) {
          _showSnackBar(AppLang.tr(context, 'password_changed_success') ?? 'تم تغيير كلمة المرور بنجاح', Colors.green);
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      // تفصيل الأخطاء عشان نعرف المشكلة فين بالظبط
      String errorMessage = AppLang.tr(context, 'system_error') ?? 'حدث خطأ في النظام';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = AppLang.tr(context, 'wrong_current_password') ?? 'كلمة المرور الحالية خطأ';
      } else if (e.code == 'too-many-requests') {
        errorMessage = AppLang.tr(context, 'too_many_requests') ?? 'محاولات كثيرة جداً، يرجى المحاولة لاحقاً';
      }
      _showSnackBar(errorMessage, Colors.red);
    } catch (e) {
      _showSnackBar(AppLang.tr(context, 'system_error') ?? 'حدث خطأ غير متوقع', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLang.tr(context, 'change_password_title') ?? 'تغيير كلمة المرور',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(AppLang.tr(context, 'change_password_desc') ?? "قم بتحديث كلمة المرور لزيادة أمان حسابك",
                style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 40),

            // 🔥 تمرير حالة الإخفاء ودالة التبديل لكل حقل
            _buildField(
              label: AppLang.tr(context, 'current_password') ?? "كلمة المرور الحالية",
              controller: _currentPasswordController,
              isDark: isDark,
              isObscured: _obscureCurrent,
              onToggleVisibility: () => setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 24),
            _buildField(
              label: AppLang.tr(context, 'new_password') ?? "كلمة المرور الجديدة",
              controller: _newPasswordController,
              isDark: isDark,
              isObscured: _obscureNew,
              onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 24),
            _buildField(
              label: AppLang.tr(context, 'confirm_new_password') ?? "تأكيد كلمة المرور الجديدة",
              controller: _confirmPasswordController,
              isDark: isDark,
              isObscured: _obscureConfirm,
              onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),

            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 5,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(AppLang.tr(context, 'update_password_btn') ?? "تحديث كلمة المرور", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(context: context, builder: (c) => const AiChatBottomSheet()),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.auto_awesome, color: Colors.white),
      ),
    );
  }

  // 🔥 تعديل دالة بناء الحقل لدعم أيقونة العين
  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required bool isDark,
    required bool isObscured,
    required VoidCallback onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: isObscured, // التحكم في الرؤية من هنا
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF1E2834) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary)),
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textHint),
            // 🔥 أيقونة العين
            suffixIcon: IconButton(
              icon: Icon(
                isObscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: AppColors.textHint,
              ),
              onPressed: onToggleVisibility,
            ),
          ),
        ),
      ],
    );
  }
}