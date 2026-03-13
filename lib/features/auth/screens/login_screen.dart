import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/localization/cubit/locale_cubit.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';
import 'email_verification_screen.dart';
import '../../home/screens/main_layout.dart';
import '../../intro/screens/onboarding_survey_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isCheckingSurvey = false;

  void _showLanguagePicker(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (BuildContext ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLang.tr(context, 'language') ?? 'اللغة / Language', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 20),
              _buildLanguageOption(context: ctx, title: 'العربية', localeCode: 'ar', isDark: isDark),
              const SizedBox(height: 12),
              _buildLanguageOption(context: ctx, title: 'English', localeCode: 'en', isDark: isDark),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageOption({required BuildContext context, required String title, required String localeCode, required bool isDark}) {
    Locale currentLocale = Localizations.localeOf(this.context);
    bool isSelected = currentLocale.languageCode == localeCode;

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        this.context.read<LocaleCubit>().changeLanguage(localeCode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.grey.shade300), width: isSelected ? 2 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? AppColors.primary : (isDark ? Colors.white : Colors.black87))),
            if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  // 🔥 الدالة المؤمنة (Bulletproof) للتشييك على السيرفاي 🔥
  Future<void> _checkSurveyAndNavigate() async {
    setState(() => _isCheckingSurvey = true);
    String? uid = CacheHelper.getData(key: 'uid');

    if (uid != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get().timeout(const Duration(seconds: 4));
        if (userDoc.exists) {
          Map<String, dynamic>? data = userDoc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('preferences')) {
            await CacheHelper.saveData(key: 'survey_completed', value: true);
            if (mounted) {
              Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainLayout()), (route) => false);
            }
            return;
          }
        }
      } catch (e) {
        print("Firebase Check Timeout/Error: $e");
        if (mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainLayout()), (route) => false);
        }
        return;
      }
    }

    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const OnboardingSurveyScreen()), (route) => false);
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
        leading: IconButton(icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black), onPressed: () => Navigator.pop(context)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/logo.png', height: 40),
            const SizedBox(width: 8),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (bounds) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: isDark ? [const Color(0xFF64B5F6), const Color(0xFF1976D2)] : [const Color(0xFF2E86AB), const Color(0xFF0A3656)]).createShader(bounds),
              child: Text("GEAR UP", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white, shadows: [Shadow(color: isDark ? const Color(0xFF64B5F6).withOpacity(0.6) : Colors.black.withOpacity(0.2), offset: Offset(0, isDark ? 0 : 2), blurRadius: isDark ? 8 : 4)])),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) async {
          // 🔥 هنا بنسمع للـ State الجديدة اللي ضفناها في الـ AuthCubit 🔥
          if (state is AuthSuccess) {
            await _checkSurveyAndNavigate();
          } else if (state is AuthNeedsSurvey) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OnboardingSurveyScreen()));
          } else if (state is AuthNeedsVerification) {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EmailVerificationScreen()));
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: Colors.red));
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(AppLang.tr(context, 'welcome_back') ?? "Welcome Back", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  Text(AppLang.tr(context, 'sign_in') ?? "Sign in to continue", style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 32),

                  Text(AppLang.tr(context, 'email') ?? "Email", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    validator: (value) => value!.isEmpty ? 'Please enter your email' : null,
                    decoration: _inputDecoration(AppLang.tr(context, 'email_hint') ?? "your@email.com", Icons.email_outlined, isDark),
                  ),
                  const SizedBox(height: 20),

                  Text(AppLang.tr(context, 'password') ?? "Password", style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    validator: (value) => value!.isEmpty ? 'Please enter your password' : null,
                    decoration: _inputDecoration(AppLang.tr(context, 'password_hint') ?? "********", Icons.lock_outline, isDark).copyWith(
                      suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textHint), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                    ),
                  ),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ForgotPasswordScreen())), child: Text(AppLang.tr(context, 'forgot_password_title') ?? "Forgot Password?", style: const TextStyle(color: AppColors.primary))),
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          context.read<AuthCubit>().login(email: _emailController.text.trim(), password: _passwordController.text.trim());
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: (state is AuthLoading || _isCheckingSurvey)
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(AppLang.tr(context, 'login') ?? "Login", style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppLang.tr(context, 'dont_have_account') ?? "Don't have an account?", style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary)),
                      const SizedBox(width: 4),
                      GestureDetector(onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SignupScreen())), child: Text(AppLang.tr(context, 'sign_up') ?? "Sign up", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 60),

                  Center(
                    child: GestureDetector(
                      onTap: () => _showLanguagePicker(context, isDark),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2834) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 5, offset: const Offset(0, 2))]),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.language, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(Localizations.localeOf(context).languageCode == 'ar' ? 'العربية' : 'English', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down, color: AppColors.textHint, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    );
  }
}