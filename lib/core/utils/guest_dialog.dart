import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart'; // 🔥 تم استيراد ملف الترجمة
import '../../features/auth/screens/login_screen.dart';

class GuestChecker {
  // 1. دالة بتعرفنا هل هو زائر ولا يوزر حقيقي
  static bool isGuest() {
    return FirebaseAuth.instance.currentUser == null;
  }

  // 2. الـ Dialog الفخم اللي بيطلع للزائر
  static void showGuestDialog(BuildContext context, String featureName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Icon(Icons.lock_outline_rounded, size: 50, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              AppLang.tr(context, 'login_required') ?? "تسجيل الدخول مطلوب",
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "${AppLang.tr(context, 'guest_sorry_prefix') ?? 'عفواً، لا يمكنك'} $featureName ${AppLang.tr(context, 'guest_sorry_suffix') ?? 'كزائر. قم بتسجيل الدخول لتستمتع بجميع مميزات GEAR UP! 🚗✨'}",
          textAlign: TextAlign.center,
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              AppLang.tr(context, 'cancel_btn') ?? "إلغاء",
              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              AppLang.tr(context, 'login') ?? "تسجيل الدخول",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}