import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/cubit/auth_state.dart';
import '../../auth/screens/login_screen.dart';
import '../../auth/screens/signup_screen.dart';
import '../../intro/screens/welcome_screen.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'published_items_screen.dart';
import 'start_selling_screen.dart';
import 'account_information_screen.dart';
import 'payments_screen.dart';
import 'my_reviews_screen.dart';
import 'admin_dashboard_screen.dart'; // 🔥 استدعاء لوحة الأدمن 🔥
import 'package:cloud_firestore/cloud_firestore.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  @override
  @override
  @override
  void initState() {
    super.initState();
    final authCubit = context.read<AuthCubit>();
    // رجعناها طبيعية بتجيب البيانات بس من غير ما تعدل حاجة في القاعدة
    if (CacheHelper.getData(key: 'uid') != null) {
      authCubit.getUserData();
    }
  }

  void _showGuestDialog(BuildContext context, String featureName) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: isDark ? const Color(0xFF161E27) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: isDark ? 0 : 10,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(AppLang.tr(context, 'login_required') ?? "تسجيل الدخول مطلوب", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Text("${AppLang.tr(context, 'guest_sorry_prefix') ?? 'عفواً، لا يمكنك'} $featureName ${AppLang.tr(context, 'guest_sorry_suffix') ?? 'كزائر. قم بتسجيل الدخول لتستمتع بجميع مميزات GEAR UP! 🚗✨'}", textAlign: TextAlign.center, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14, height: 1.6)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())); },
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  child: Text(AppLang.tr(context, 'login') ?? "تسجيل الدخول", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text(AppLang.tr(context, 'cancel_btn') ?? "إلغاء", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isLoggedIn = CacheHelper.getData(key: 'uid') != null;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

    return Scaffold(
      backgroundColor: screenBgColor,
      body: SafeArea(
        child: isLoggedIn ? _buildLoggedInProfile(isDark) : _buildUnloggedProfile(isDark),
      ),
    );
  }

  Widget _buildLoggedInProfile(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final user = context.read<AuthCubit>().currentUser;

          if (state is GetUserLoading && user == null) {
            return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40.0), child: CircularProgressIndicator(color: AppColors.primary)));
          }

          String name = user?.name ?? 'User';
          String email = user?.email ?? '';
          String phone = user?.phone ?? '';
          String profileImageUrl = user?.profileImage ?? '';
          bool isAdmin = user?.role == 'admin'; // 🔥 الباسورد السري للأدمن 🔥

          String initials = "U";
          if (user != null && name.isNotEmpty) {
            List<String> nameParts = name.trim().split(' ');
            if (nameParts.length > 1 && nameParts[1].isNotEmpty) {
              initials = '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
            } else {
              initials = name[0].toUpperCase();
            }
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountInformationScreen())),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF1E3A8A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 75, height: 75,
                        decoration: BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                          image: profileImageUrl.isNotEmpty ? DecorationImage(image: CachedNetworkImageProvider(profileImageUrl), fit: BoxFit.cover) : null,
                        ),
                        child: profileImageUrl.isEmpty ? Center(child: Text(initials, style: const TextStyle(color: AppColors.primary, fontSize: 26, fontWeight: FontWeight.w900))) : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            if (email.isNotEmpty) Text(email, style: const TextStyle(color: Colors.white70, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            if (phone.isNotEmpty) Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            // 🔥 الكود ده هيطبعلك الـ ID بتاعك عشان تعرف إنت مين في الفايربيز 🔥

                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // 🔥 قسم المدير العام (مش هيظهر غير ليك) 🔥
              if (isAdmin) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                  child: Text(AppLang.tr(context, 'admin_section') ?? "الإدارة", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
                ),
                _buildMenuCard(
                  isDark: isDark,
                  title: AppLang.tr(context, 'admin_dashboard') ?? "لوحة تحكم الإدارة",
                  subtitle: AppLang.tr(context, 'admin_dashboard_desc') ?? "إحصائيات، مستخدمين، وبلاغات",
                  icon: Icons.admin_panel_settings_rounded, iconColor: const Color(0xFF9C27B0),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboardScreen())),
                ),
                const SizedBox(height: 16),
              ],

              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                child: Text(AppLang.tr(context, 'my_account') ?? 'حسابي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              ),

              _buildMenuCard(
                isDark: isDark, title: AppLang.tr(context, 'start_selling') ?? 'Start Selling', subtitle: AppLang.tr(context, 'list_new_item') ?? 'List a new item', icon: Icons.attach_money_outlined, iconColor: const Color(0xFF4CAF50), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StartSellingScreen())),
              ),
              _buildMenuCard(
                isDark: isDark, title: AppLang.tr(context, 'published_items') ?? 'Published Items', subtitle: AppLang.tr(context, 'manage_listings') ?? 'Manage your listings', icon: Icons.inventory_2_outlined, iconColor: const Color(0xFF2196F3), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PublishedItemsScreen())),
              ),
              _buildMenuCard(
                isDark: isDark, title: AppLang.tr(context, 'my_reviews') ?? "تقييماتي", subtitle: AppLang.tr(context, 'manage_previous_reviews') ?? "إدارة تقييماتك السابقة للسيارات", icon: Icons.star_rate_rounded, iconColor: const Color(0xFFFFC107), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MyReviewsScreen())),
              ),
              _buildMenuCard(
                isDark: isDark, title: AppLang.tr(context, 'edit_profile') ?? 'Edit Profile', subtitle: AppLang.tr(context, 'edit_profile_sub') ?? 'Update your information', icon: Icons.edit_outlined, iconColor: const Color(0xFF00BCD4), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen())),
              ),
              _buildMenuCard(
                isDark: isDark, title: AppLang.tr(context, 'payments') ?? 'Payments', subtitle: AppLang.tr(context, 'manage_payment_methods') ?? 'Manage payment methods', icon: Icons.credit_card_outlined, iconColor: const Color(0xFF4CAF50), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PaymentsScreen())),
              ),

              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 16.0, bottom: 16.0),
                child: Text(AppLang.tr(context, 'app_section') ?? 'التطبيق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              ),

              _buildMenuCard(
                isDark: isDark, title: AppLang.tr(context, 'settings') ?? 'Settings', subtitle: AppLang.tr(context, 'settings_sub') ?? 'App preferences', icon: Icons.settings_outlined, iconColor: const Color(0xFF9E9E9E), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await context.read<AuthCubit>().logout();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const WelcomeScreen()), (route) => false);
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.white, size: 22),
                  label: Text(AppLang.tr(context, 'logout') ?? 'تسجيل الخروج', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.0)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545), padding: const EdgeInsets.symmetric(vertical: 20), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                ),
              ),

              const SizedBox(height: 100),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUnloggedProfile(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, shape: BoxShape.circle, border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFEEEEEE), width: 2)),
            child: Image.asset('assets/images/logo.png', height: 60, width: 60),
          ),
          const SizedBox(height: 16),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: isDark ? [const Color(0xFF64B5F6), const Color(0xFF1976D2)] : [const Color(0xFF2E86AB), const Color(0xFF0A3656)]).createShader(bounds),
            child: Text("GEAR UP", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white, shadows: [Shadow(color: isDark ? const Color(0xFF64B5F6).withOpacity(0.6) : Colors.black.withOpacity(0.3), offset: Offset(0, isDark ? 0 : 3), blurRadius: isDark ? 10 : 5)])),          ),
          const SizedBox(height: 4),
          Text(AppLang.tr(context, 'egypt_car_app') ?? 'Egypt Car App', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 40),

          _buildMenuCard(isDark: isDark, title: AppLang.tr(context, 'start_selling') ?? 'Start Selling', subtitle: AppLang.tr(context, 'list_new_item') ?? 'List a new item', icon: Icons.attach_money_outlined, iconColor: const Color(0xFF4CAF50), onTap: () => _showGuestDialog(context, AppLang.tr(context, 'publish_ads_feature') ?? "نشر إعلانات")),
          _buildMenuCard(isDark: isDark, title: AppLang.tr(context, 'published_items') ?? 'Published Items', subtitle: AppLang.tr(context, 'manage_listings') ?? 'Manage your listings', icon: Icons.inventory_2_outlined, iconColor: const Color(0xFF2196F3), onTap: () => _showGuestDialog(context, AppLang.tr(context, 'manage_ads_feature') ?? "إدارة الإعلانات")),
          _buildMenuCard(isDark: isDark, title: AppLang.tr(context, 'my_reviews') ?? "تقييماتي", subtitle: AppLang.tr(context, 'manage_previous_reviews') ?? "إدارة تقييماتك السابقة للسيارات", icon: Icons.star_rate_rounded, iconColor: const Color(0xFFFFC107), onTap: () => _showGuestDialog(context, AppLang.tr(context, 'manage_reviews_feature') ?? "إدارة التقييمات")),

          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LoginScreen())), icon: const Icon(Icons.login, color: Colors.white, size: 20), label: Text(AppLang.tr(context, 'login') ?? 'Login', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen())), icon: Icon(Icons.person_add_outlined, color: isDark ? Colors.white : Colors.black, size: 20), label: Text(AppLang.tr(context, 'sign_up') ?? 'Sign Up', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: isDark ? Colors.white24 : AppColors.borderLight), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))))),
          const SizedBox(height: 40),

          _buildMenuCard(isDark: isDark, title: AppLang.tr(context, 'settings') ?? 'Settings', subtitle: AppLang.tr(context, 'settings_sub') ?? 'App preferences', icon: Icons.settings_outlined, iconColor: const Color(0xFF9E9E9E), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()))),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildMenuCard({required bool isDark, required String title, required String subtitle, required IconData icon, required Color iconColor, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 15, offset: const Offset(0, 6))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500))])),
            Icon(Icons.arrow_forward_ios, color: isDark ? Colors.white54 : AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}