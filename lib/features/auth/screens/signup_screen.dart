import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final String _baseUrl = 'https://gear-up-backend.vercel.app';
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Future<void> _sendWelcomeEmail(String userEmail, String userName) async {
    try {
      await _dio.post(
        '$_baseUrl/api/send-welcome-email',
        data: {'userEmail': userEmail, 'userName': userName},
      );
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
        bool isAr = currentLang == 'ar';

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
                  child: const Text("GEAR UP", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
                ),
              ],
            ),
            centerTitle: true,
          ),
          body: BlocConsumer<AuthCubit, AuthState>(
            listener: (context, state) {
              if (state is AuthSuccess || state is AuthNeedsSurvey) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const OnboardingSurveyScreen()), (route) => false);
              }
              else if (state is AuthNeedsVerification) {
                _sendWelcomeEmail(_emailController.text.trim(), _nameController.text.trim());
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const EmailVerificationScreen()), (route) => false);
              }
              else if (state is AuthError) {
                // 🔥 تم تصليح الـ State.error والترجمة الذكية 🔥
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, state.error) ?? state.error), backgroundColor: Colors.red));
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
                      const SizedBox(height: 32),

                      // 🔥 أزرار الدخول السريع (جوجل وفيسبوك جمب بعض) 🔥
                      Row(
                        children: [
                          // --------- زرار جوجل ---------
                          Expanded(
                            child: Container(
                              height: 58,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1F26) : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white, width: 1),
                                boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.4) : AppColors.primary.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 6))],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: state is AuthLoading ? null : () => context.read<AuthCubit>().signInWithGoogle(),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset('assets/images/google.png', height: 24),
                                      const SizedBox(width: 10),
                                      Text("Google", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // --------- زرار فيسبوك ---------
                          Expanded(
                            child: Container(
                              height: 58,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1A1F26) : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.white, width: 1),
                                boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.4) : AppColors.primary.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 6))],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: state is AuthLoading ? null : () => context.read<AuthCubit>().signInWithFacebook(),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 28),
                                      const SizedBox(width: 8),
                                      Text("Facebook", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      Row(
                        children: [
                          Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.grey[300], thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              AppLang.tr(context, 'or_sign_up_with_email') ?? "Or sign up with email",
                              style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500], fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          Expanded(child: Divider(color: isDark ? Colors.white12 : Colors.grey[300], thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 30),

                      _buildLabel(AppLang.tr(context, 'full_name') ?? "Full Name", isDark),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        validator: (value) => value!.isEmpty ? (AppLang.tr(context, 'name_required') ?? 'Please enter your name') : null,
                        decoration: _inputDecoration(AppLang.tr(context, 'full_name_hint') ?? "Enter your name", Icons.person_outline, isDark),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel(AppLang.tr(context, 'email') ?? "Email", isDark),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        validator: (value) {
                          if (value == null || value.isEmpty) return AppLang.tr(context, 'email_required') ?? 'Please enter your email';
                          if (!value.toLowerCase().trim().endsWith('@gmail.com')) return AppLang.tr(context, 'gmail_only') ?? 'يجب استخدام حساب Gmail فقط (@gmail.com)';
                          return null;
                        },
                        decoration: _inputDecoration("your.name@gmail.com", Icons.email_outlined, isDark),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel(AppLang.tr(context, 'phone_number') ?? "Phone Number", isDark),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 11,
                        textDirection: TextDirection.ltr,
                        textAlign: isAr ? TextAlign.right : TextAlign.left,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        validator: (value) {
                          if (value == null || value.isEmpty) return AppLang.tr(context, 'phone_required') ?? 'يرجى إدخال رقم الهاتف';
                          if (value.length != 11) return AppLang.tr(context, 'phone_length') ?? 'رقم الهاتف يجب أن يكون 11 رقماً';
                          if (!value.startsWith('01')) return AppLang.tr(context, 'phone_start') ?? 'يجب أن يبدأ رقم الهاتف بـ 01';
                          return null;
                        },
                        decoration: _inputDecoration("\u200E01012345678", Icons.phone_outlined, isDark).copyWith(counterText: ""),
                      ),
                      const SizedBox(height: 16),

                      _buildLabel(AppLang.tr(context, 'password') ?? "Password", isDark),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        validator: (value) {
                          if (value == null || value.isEmpty) return AppLang.tr(context, 'password_required') ?? 'Please enter your password';
                          if (value.length < 8) return AppLang.tr(context, 'password_length') ?? 'Password must be at least 8 characters';
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
                          if (value != _passwordController.text) return AppLang.tr(context, 'passwords_do_not_match') ?? 'Passwords do not match';
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

                      // 🔥 زرار تغيير اللغة بعد التنظيف (شيلنا CacheHelper لأنه بيحصل جوه الـ Cubit) 🔥
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
                              onChanged: (String? newValue) {
                                if (newValue != null && newValue != currentLang) {
                                  // Cubit handles CacheHelper internally now!
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