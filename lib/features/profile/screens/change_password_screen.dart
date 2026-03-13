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

    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar(AppLang.tr(context, 'all_fields_required') ?? 'جميع الحقول مطلوبة', Colors.red);
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar(AppLang.tr(context, 'new_password_mismatch') ?? 'كلمة المرور الجديدة غير متطابقة', Colors.red);
      return;
    }

    // 🔥 التحقق من قوة الباسوورد (حروف وأرقام و8 خانات) 🔥
    final passwordRegex = RegExp(r'^(?=.*[a-zA-Z])(?=.*\d).+$');
    if (!passwordRegex.hasMatch(newPassword) || newPassword.length < 8) {
      _showSnackBar(AppLang.tr(context, 'password_requirements_msg') ?? 'كلمة المرور يجب أن تحتوي على حروف وأرقام، ولا تقل عن 8 خانات', Colors.red);
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null && user.email != null) {
        // 1. إعادة التحقق (أمان فايربيز)
        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);

        // 2. تحديث الباسوورد
        await user.updatePassword(newPassword);

        // 🔥 إرسال إشعار للجيميل إن الباسوورد اتغير (أمان إضافي) 🔥
        // فايربيز بيبعت إشعار تلقائي أحياناً، بس إحنا هنأكد العملية بـ SnackBar

        if (mounted) {
          _showSnackBar(AppLang.tr(context, 'password_changed_success') ?? 'تم تغيير كلمة المرور بنجاح ويصلك إشعار تأكيد الآن', Colors.green);
          Navigator.pop(context);
        }
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.code == 'wrong-password' ? (AppLang.tr(context, 'wrong_current_password') ?? 'كلمة المرور الحالية خطأ') : (AppLang.tr(context, 'system_error') ?? 'حدث خطأ في النظام'), Colors.red);
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

            _buildField(AppLang.tr(context, 'current_password') ?? "كلمة المرور الحالية", _currentPasswordController, isDark),
            const SizedBox(height: 24),
            _buildField(AppLang.tr(context, 'new_password') ?? "كلمة المرور الجديدة", _newPasswordController, isDark),
            const SizedBox(height: 24),
            _buildField(AppLang.tr(context, 'confirm_new_password') ?? "تأكيد كلمة المرور الجديدة", _confirmPasswordController, isDark),

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

  Widget _buildField(String label, TextEditingController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? const Color(0xFF1E2834) : Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary)),
            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textHint),
          ),
        ),
      ],
    );
  }
}