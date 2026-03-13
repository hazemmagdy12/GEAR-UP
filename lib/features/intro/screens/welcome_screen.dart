import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/signup_screen.dart';
import '../../home/screens/main_layout.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🔥 ألوان الخلفية الفخمة بتاعتنا 🔥
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFE3F2FD);

    return Scaffold(
      backgroundColor: screenBgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              Image.asset(
                'assets/images/logo.png',
                height: 120,
                width: 120,
              ),

              const SizedBox(height: 4),

              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [const Color(0xFF64B5F6), const Color(0xFF1976D2)]
                      : [const Color(0xFF2E86AB), const Color(0xFF0A3656)],
                ).createShader(bounds),
                child: Text(
                  "GEAR UP",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: isDark ? const Color(0xFF64B5F6).withOpacity(0.6) : Colors.black.withOpacity(0.3),
                        offset: Offset(0, isDark ? 0 : 3),
                        blurRadius: isDark ? 10 : 5,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                AppLang.tr(context, 'premium_companion') ?? "Your Premium Auto Companion",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),

              const Spacer(flex: 1),

              // لو اليوزر داس تخطي، هيدخل الرئيسية بس كـ Guest
              OutlinedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainLayout()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  AppLang.tr(context, 'skip_to_home') ?? "تخطي للرئيسية",
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(AppLang.tr(context, 'login') ?? "تسجيل الدخول", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignupScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(AppLang.tr(context, 'sign_up') ?? "إنشاء حساب", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}