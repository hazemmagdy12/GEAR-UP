import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // 🔥 دالة إرسال رابط إعادة تعيين الباسوورد بعد التنظيف والترجمة 🔥
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLang.tr(context, 'reset_link_sent') ?? 'تم إرسال رابط إعادة تعيين كلمة المرور إلى بريدك الإلكتروني'),
              backgroundColor: Colors.green
          ),
        );
        Navigator.pop(context); // نرجعه لشاشة اللوجين
      }
    } on FirebaseAuthException catch (e) {
      String message = AppLang.tr(context, 'something_went_wrong') ?? "حدث خطأ ما";

      if (e.code == 'user-not-found') {
        message = AppLang.tr(context, 'user_not_found') ?? "هذا الحساب غير موجود";
      } else if (e.code == 'invalid-email') {
        message = AppLang.tr(context, 'invalid_email_format') ?? "صيغة البريد الإلكتروني غير صحيحة";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 40),
            const SizedBox(width: 8),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [const Color(0xFF64B5F6), const Color(0xFF1976D2)]
                    : [const Color(0xFF2E86AB), const Color(0xFF0A3656)],
              ).createShader(bounds),
              child: const Text(
                "GEAR UP",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(AppLang.tr(context, 'forgot_password_title') ?? "Forgot Password",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 12),
              Text(
                AppLang.tr(context, 'forgot_password_desc') ?? "Enter your email to receive a password reset link.",
                style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              Text(AppLang.tr(context, 'email') ?? "Email",
                  style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress, // 🔥 بيفتح كيبورد الإيميل علطول
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                validator: (val) {
                  // 🔥 Regex ذكي للتحقق من الإيميل قبل الإرسال 🔥
                  if (val == null || val.isEmpty) {
                    return AppLang.tr(context, 'email_required') ?? "برجاء إدخال الإيميل";
                  }
                  if (!RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(val)) {
                    return AppLang.tr(context, 'invalid_email_format') ?? "صيغة البريد الإلكتروني غير صحيحة";
                  }
                  return null;
                },
                decoration: _inputDecoration(AppLang.tr(context, 'email_hint') ?? "your@email.com", Icons.email_outlined, isDark),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(AppLang.tr(context, 'send_reset_link') ?? "Send Link",
                      style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLang.tr(context, 'back_to_login') ?? "Back to Login",
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textHint),
      prefixIcon: Icon(icon, color: AppColors.textHint),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );
  }
}