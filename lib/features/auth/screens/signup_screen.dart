import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🔥 المكتبة دي عشان نجبره يكتب أرقام بس 🔥
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/localization/cubit/locale_cubit.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';
import '../../intro/screens/onboarding_survey_screen.dart';
import '../../../core/local_storage/cache_helper.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Dio _dio = Dio();

  final String _baseUrl = 'https://d897c33f-6257-4a85-9126-2bc9c6be829e-00-dd6nn6kccr87.spock.replit.dev';

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _sendWelcomeEmail(String userEmail, String userName) async {
    try {
      await _dio.post(
        '$_baseUrl/api/send-welcome-email',
        data: {'userEmail': userEmail, 'userName': userName},
      );
      debugPrint('Welcome email sent successfully to $userEmail!');
    } catch (e) {
      debugPrint('Welcome email failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFE3F2FD);

    return BlocBuilder<LocaleCubit, Locale>(
      builder: (context, locale) {
        String currentLang = locale.languageCode;

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
            listener: (context, state) {
              if (state is AuthSuccess) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const OnboardingSurveyScreen()), (route) => false);
              }
              else if (state is AuthNeedsVerification) {
                _sendWelcomeEmail(_emailController.text.trim(), _nameController.text.trim());

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const EmailVerificationScreen()),
                      (route) => false,
                );
              }
              else if (state is AuthError) {
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
                      const SizedBox(height: 10),
                      Text(AppLang.tr(context, 'create_account') ?? "Create Account", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 8),
                      Text(AppLang.tr(context, 'join_gear_up') ?? "Join GEAR UP today", style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 16)),
                      const SizedBox(height: 24),

                      _buildLabel(AppLang.tr(context, 'full_name') ?? "Full Name", isDark),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        validator: (value) => value!.isEmpty ? 'Please enter your name' : null,
                        decoration: _inputDecoration(AppLang.tr(context, 'full_name_hint') ?? "Enter your name", Icons.person_outline, isDark),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel(AppLang.tr(context, 'email') ?? "Email", isDark),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress, // 🔥 بيفتح كيبورد الإيميل الإنجليزي أوتوماتيك
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your email';
                          if (!value.toLowerCase().trim().endsWith('@gmail.com')) return 'يجب استخدام حساب Gmail فقط (@gmail.com)';
                          return null;
                        },
                        decoration: _inputDecoration("your.name@gmail.com", Icons.email_outlined, isDark),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel(AppLang.tr(context, 'phone_number') ?? "Phone Number", isDark),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        // 🔥 دي بتجبر الكيبورد واليوزر إنه يكتب أرقام إنجليزي فقط 🔥
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 11, // بيمنع اليوزر إنه يكتب أكتر من 11 رقم
                        // 🔥 ده بيخلي النص دايماً من اليسار لليمين مهما كانت لغة الموبايل
                        textDirection: TextDirection.ltr,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'يرجى إدخال رقم الهاتف';
                          if (value.length != 11) return 'رقم الهاتف يجب أن يكون 11 رقماً';
                          if (!value.startsWith('01')) return 'يجب أن يبدأ رقم الهاتف بـ 01';
                          return null;
                        },
                        decoration: _inputDecoration(
                          // \u200E ده رمز سحري بيخلي الأرقام معدولة في العربي
                            "\u200E01012345678",
                            Icons.phone_outlined,
                            isDark
                        ).copyWith(counterText: ""), // عشان يخفي العداد بتاع الحروف (0/11) اللي بيظهر تحت الحقل
                      ),
                      const SizedBox(height: 16),

                      _buildLabel(AppLang.tr(context, 'password') ?? "Password", isDark),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your password';
                          if (value.length < 8) return 'Password must be at least 8 characters';
                          if (!RegExp(r'[a-zA-Z]').hasMatch(value)) return 'Password must contain at least one letter';
                          if (!RegExp(r'[0-9]').hasMatch(value)) return 'Password must contain at least one number';
                          return null;
                        },
                        decoration: _inputDecoration(AppLang.tr(context, 'password_hint') ?? "********", Icons.lock_outline, isDark).copyWith(
                          suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textHint), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel(AppLang.tr(context, 'confirm_password') ?? "Confirm Password", isDark),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        validator: (value) {
                          if (value != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                        decoration: _inputDecoration(AppLang.tr(context, 'password_hint') ?? "********", Icons.lock_outline, isDark).copyWith(
                          suffixIcon: IconButton(icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility, color: AppColors.textHint), onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
                        ),
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              context.read<AuthCubit>().signUp(email: _emailController.text.trim(), password: _passwordController.text.trim(), name: _nameController.text.trim(), phone: _phoneController.text.trim());
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                          child: state is AuthLoading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text(AppLang.tr(context, 'sign_up') ?? "Sign Up", style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(AppLang.tr(context, 'already_have_account') ?? "Already have an account?", style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary)),
                          const SizedBox(width: 4),
                          GestureDetector(onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen())), child: Text(AppLang.tr(context, 'login') ?? "Login", style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
                        ],
                      ),

                      const SizedBox(height: 40),

                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2834) : Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: currentLang,
                              icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                              dropdownColor: isDark ? const Color(0xFF1E2834) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              items: [
                                DropdownMenuItem(
                                  value: 'en',
                                  child: Row(children: [const Icon(Icons.language, color: AppColors.primary, size: 18), const SizedBox(width: 8), Text('English', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w600))]),
                                ),
                                DropdownMenuItem(
                                  value: 'ar',
                                  child: Row(children: [const Icon(Icons.language, color: AppColors.primary, size: 18), const SizedBox(width: 8), Text('العربية', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14, fontWeight: FontWeight.w600))]),
                                ),
                              ],
                              onChanged: (String? newValue) async {
                                if (newValue != null && newValue != currentLang) {
                                  await CacheHelper.saveData(key: 'lang', value: newValue);
                                  context.read<LocaleCubit>().changeLanguage(newValue);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(padding: const EdgeInsets.only(bottom: 8.0), child: Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)));
  }

  InputDecoration _inputDecoration(String hint, IconData icon, bool isDark) {
    return InputDecoration(
      hintText: hint, hintStyle: const TextStyle(color: AppColors.textHint), prefixIcon: Icon(icon, color: AppColors.textHint), filled: true, fillColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    );
  }
}