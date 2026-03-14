import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/cubit/theme_cubit.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/localization/cubit/locale_cubit.dart';
import '../../../core/local_storage/cache_helper.dart';
import 'help_center_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isClearingCache = false;

  // 🔥 دالة إظهار رسالة التحذير قبل المسح 🔥
  void _showClearCacheWarning(BuildContext context, bool isDarkMode) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDarkMode ? const Color(0xFF161E27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_sweep_rounded, size: 40, color: Colors.redAccent),
              ),
              const SizedBox(height: 20),
              Text(
                AppLang.tr(context, 'clear_cache_title') ?? "تأكيد مسح الذاكرة",
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                AppLang.tr(context, 'clear_cache_desc') ?? "هل أنت متأكد من مسح الذاكرة المؤقتة للصور والبحث؟ سيؤدي هذا لتوفير مساحة بهاتفك، ولن يتم تسجيل خروجك من حسابك.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        AppLang.tr(context, 'cancel_btn') ?? "إلغاء",
                        style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx); // يقفل الديالوج الأول
                        _executeClearCache(); // ينفذ المسح الحقيقي
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        AppLang.tr(context, 'confirm_clear') ?? "نعم، امسح",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 دالة التنفيذ الحقيقية بعد الموافقة 🔥
  Future<void> _executeClearCache() async {
    setState(() => _isClearingCache = true);

    try {
      await DefaultCacheManager().emptyCache();
      await CacheHelper.removeData(key: 'gear_up_cars_recent_searches_persistent');
      await CacheHelper.removeData(key: 'gear_up_parts_recent_searches_persistent');

      await Future.delayed(const Duration(milliseconds: 800));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLang.tr(context, 'cache_cleared') ?? 'تم مسح الذاكرة المؤقتة بنجاح! ✨'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error clearing cache: $e");
    } finally {
      if (mounted) {
        setState(() => _isClearingCache = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        return BlocBuilder<LocaleCubit, Locale>(
          builder: (context, locale) {

            final isDarkMode = themeMode == ThemeMode.dark;
            final isEnglish = locale.languageCode == 'en';
            final Color screenBgColor = isDarkMode ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

            return Scaffold(
              backgroundColor: screenBgColor,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDarkMode ? Colors.white10 : AppColors.primary.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12),
                      color: isDarkMode ? const Color(0xFF161E27).withOpacity(0.8) : Colors.white.withOpacity(0.7),
                    ),
                    child: Icon(Icons.arrow_back, size: 24, color: isDarkMode ? Colors.white : AppColors.primary),
                  ),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLang.tr(context, 'settings') ?? 'Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDarkMode ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(AppLang.tr(context, 'manage_preferences') ?? 'Manage Preferences', style: TextStyle(color: isDarkMode ? Colors.white70 : AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 32),

                    Text(AppLang.tr(context, 'app_preferences') ?? 'App Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                    const SizedBox(height: 16),

                    _buildSwitchTile(
                      isDarkMode: isDarkMode,
                      title: AppLang.tr(context, 'dark_mode') ?? 'Dark Mode',
                      subtitle: isDarkMode ? (AppLang.tr(context, 'dark_enabled') ?? 'Dark Enabled') : (AppLang.tr(context, 'light_enabled') ?? 'Light Enabled'),
                      icon: Icons.light_mode_outlined,
                      value: isDarkMode,
                      onChanged: (val) {
                        context.read<ThemeCubit>().toggleTheme();
                      },
                    ),

                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(20),
                      decoration: _cardDecoration(isDarkMode),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E2834) : AppColors.surfaceLight, shape: BoxShape.circle),
                                child: const Icon(Icons.language, color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppLang.tr(context, 'language') ?? 'Language', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87)),
                                    const SizedBox(height: 4),
                                    Text(AppLang.tr(context, 'select_language') ?? 'Select Language', style: TextStyle(color: isDarkMode ? Colors.white70 : AppColors.textSecondary, fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => context.read<LocaleCubit>().changeLanguage('en'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: isEnglish ? AppColors.primary : (isDarkMode ? const Color(0xFF1E2834) : Colors.white),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isEnglish ? AppColors.primary : (isDarkMode ? Colors.white10 : AppColors.borderLight)),
                                    ),
                                    child: Center(
                                      child: Text("English (US)", style: TextStyle(color: isEnglish ? Colors.white : (isDarkMode ? Colors.white : Colors.black87), fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => context.read<LocaleCubit>().changeLanguage('ar'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    decoration: BoxDecoration(
                                      color: !isEnglish ? AppColors.primary : (isDarkMode ? const Color(0xFF1E2834) : Colors.white),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: !isEnglish ? AppColors.primary : (isDarkMode ? Colors.white10 : AppColors.borderLight)),
                                    ),
                                    child: Center(
                                      child: Text("Arabic (العربية)", style: TextStyle(color: !isEnglish ? Colors.white : (isDarkMode ? Colors.white : Colors.black87), fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Text(AppLang.tr(context, 'security_privacy') ?? 'Security & Privacy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                    const SizedBox(height: 16),

                    _buildNavigationTile(
                      isDarkMode: isDarkMode,
                      title: AppLang.tr(context, 'privacy_policy') ?? 'Privacy Policy',
                      subtitle: AppLang.tr(context, 'terms_privacy') ?? 'Terms & Privacy',
                      icon: Icons.shield_outlined,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacyPolicyScreen())),
                    ),

                    const SizedBox(height: 8),
                    Text(AppLang.tr(context, 'support_about') ?? 'Support & About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                    const SizedBox(height: 16),

                    _buildNavigationTile(
                      isDarkMode: isDarkMode,
                      title: AppLang.tr(context, 'help_center') ?? 'Help Center',
                      subtitle: AppLang.tr(context, 'get_support') ?? 'Get Support',
                      icon: Icons.help_outline,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpCenterScreen())),
                    ),

                    // 🔥 زرار مسح الكاش مع الديالوج الجديد 🔥
                    GestureDetector(
                      onTap: _isClearingCache ? null : () => _showClearCacheWarning(context, isDarkMode),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(18),
                        decoration: _cardDecoration(isDarkMode),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF3A1C1C) : const Color(0xFFFDE8E8), shape: BoxShape.circle),
                              child: _isClearingCache
                                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2))
                                  : const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppLang.tr(context, 'clear_cache') ?? 'مسح الذاكرة المؤقتة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87)),
                                  const SizedBox(height: 4),
                                  Text(AppLang.tr(context, 'free_up_space') ?? 'تفريغ مساحة التخزين', style: TextStyle(color: isDarkMode ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, color: isDarkMode ? Colors.white54 : AppColors.textHint, size: 16),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    Center(
                      child: Column(
                        children: [
                          Text(AppLang.tr(context, 'version') ?? 'Version 2.0.0', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(AppLang.tr(context, 'copyright') ?? '© 2026 GEAR UP. All rights reserved.', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  BoxDecoration _cardDecoration(bool isDarkMode) {
    return BoxDecoration(
      color: isDarkMode ? const Color(0xFF161E27) : Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12, width: 1),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.04), blurRadius: 15, offset: const Offset(0, 6))],
    );
  }

  Widget _buildSwitchTile({required bool isDarkMode, required String title, required String subtitle, required IconData icon, required bool value, required Function(bool) onChanged}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(isDarkMode),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E2834) : AppColors.surfaceLight, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: isDarkMode ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({required bool isDarkMode, required String title, String? subtitle, IconData? icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(isDarkMode),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E2834) : AppColors.surfaceLight, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDarkMode ? Colors.white : Colors.black87)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: isDarkMode ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: isDarkMode ? Colors.white54 : AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}