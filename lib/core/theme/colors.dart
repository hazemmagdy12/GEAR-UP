import 'package:flutter/material.dart';

class AppColors {
  // 1. الألوان المشتركة (ثابتة في اللايت والدارك)
  static const Color primary = Color(0xFF1F5F8B);
  static const Color secondary = Color(0xFF2C2C2C);
  static const Color textHint = Color(0xFF9CA3AF);

  // ==========================================
  // 2. ألوان اللايت مود (Light Mode)
  // ==========================================
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);    // للكروت والخلفيات
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color borderLight = Color(0xFFE5E7EB);

  // ==========================================
  // 3. ألوان الدارك مود (Dark Mode) - الفخامة كلها
  // ==========================================
  static const Color backgroundDark = Color(0xFF121212); // أسود مريح للعين مش فاقع
  static const Color surfaceDark = Color(0xFF1E1E1E);    // رمادي غامق جداً للكروت عشان تبرز
  static const Color textPrimaryDark = Color(0xFFF9FAFB); // أبيض للنصوص عشان تقرأ بوضوح
  static const Color textSecondaryDark = Color(0xFF9CA3AF); // رمادي فاتح للنصوص الفرعية
  static const Color borderDark = Color(0xFF333333);     // حدود غامقة شيك

  // ==========================================
  // ألوان قديمة (موجودة عشان كودك القديم ميضربش لحد ما ننضفه)
  // ==========================================
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF3F4F6);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);
  // الألوان الجديدة للتدرج الذهبي البريميوم
  static const Color premiumGoldStart = Color(0xFFFBF1C9); // ذهبي فاتح
  static const Color premiumGoldEnd = Color(0xFFC6A664);   // ذهبي غامق
  static const Color premiumGoldShadow = Color(0x66C6A664); // ظل ذهبي شفاف
}