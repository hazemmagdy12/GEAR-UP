import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import 'reported_cars_screen.dart';
// 🔥 هنحتاج الشاشة دي عشان نفتحها لما ندوس على الزرار الجديد
import 'reported_reviews_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  int _totalUsers = 0;
  int _totalCars = 0;
  int _totalParts = 0;
  int _reportedCars = 0;
  int _reportedReviews = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final usersSnap = await FirebaseFirestore.instance.collection('users').count().get();
      final carsSnap = await FirebaseFirestore.instance.collection('cars').count().get();
      // السطر ده هو اللي بيجيب عدد قطع الغيار من قاعدة البيانات
      final partsSnap = await FirebaseFirestore.instance.collection('spare_parts').count().get();
      final reportedCarsSnap = await FirebaseFirestore.instance.collection('reported_cars').where('status', isEqualTo: 'pending').count().get();
      final reportedReviewsSnap = await FirebaseFirestore.instance.collection('reported_reviews').where('status', isEqualTo: 'pending').count().get();

      if (mounted) {
        setState(() {
          _totalUsers = usersSnap.count ?? 0;
          _totalCars = carsSnap.count ?? 0;
          _totalParts = partsSnap.count ?? 0; // تخزين عدد قطع الغيار
          _reportedCars = reportedCarsSnap.count ?? 0;
          _reportedReviews = reportedReviewsSnap.count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLang.tr(context, 'fetch_stats_error') ?? "فشل جلب الإحصائيات")));
      }
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
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF161E27) : Colors.white.withOpacity(0.7),
            ),
            child: Icon(Icons.arrow_back, size: 24, color: isDark ? Colors.white : AppColors.primary),
          ),
        ),
        title: Text(AppLang.tr(context, 'control_panel') ?? "لوحة التحكم", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w900, fontSize: 22)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
        onRefresh: _fetchStats,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLang.tr(context, 'overview') ?? "نظرة عامة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.1,
                children: [
                  _buildStatCard(AppLang.tr(context, 'users_count') ?? "المستخدمين", _totalUsers.toString(), Icons.people_alt_outlined, Colors.blue, isDark),
                  _buildStatCard(AppLang.tr(context, 'active_cars_count') ?? "السيارات النشطة", _totalCars.toString(), Icons.directions_car_outlined, Colors.green, isDark),

                  // 🔥 التعديل هنا: ضفت الكارت الخاص بقطع الغيار
                  _buildStatCard(AppLang.tr(context, 'spare_parts_count') ?? "قطع الغيار", _totalParts.toString(), Icons.build_outlined, Colors.purple, isDark),

                  _buildStatCard(AppLang.tr(context, 'pending_reports_count') ?? "إعلانات مبلغ عنها", _reportedCars.toString(), Icons.report_problem_outlined, Colors.redAccent, isDark),
                  _buildStatCard(AppLang.tr(context, 'reported_reviews_count') ?? "تعليقات مسيئة", _reportedReviews.toString(), Icons.comments_disabled_outlined, Colors.orange, isDark),
                ],
              ),
              const SizedBox(height: 40),
              Text(AppLang.tr(context, 'platform_management') ?? "إدارة المنصة", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 16),

              _buildAdminActionCard(
                title: "${AppLang.tr(context, 'manage_reports_btn') ?? 'مراجعة الإعلانات'} ($_reportedCars)",
                subtitle: AppLang.tr(context, 'review_reported_cars') ?? "مراجعة السيارات والقطع المبلغ عنها وحذفها",
                icon: Icons.gavel_rounded,
                isDark: isDark,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportedCarsScreen())).then((_) => _fetchStats());
                },
              ),

              _buildAdminActionCard(
                title: "${AppLang.tr(context, 'manage_reviews_reports') ?? 'مراجعة التعليقات'} ($_reportedReviews)",
                subtitle: AppLang.tr(context, 'review_reported_comments_desc') ?? "مراجعة وحذف التعليقات التي تحتوي على إساءة",
                icon: Icons.speaker_notes_off_outlined,
                isDark: isDark,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportedReviewsScreen())).then((_) => _fetchStats());
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
          const Spacer(),
          Text(count, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: AppColors.textHint, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAdminActionCard({required String title, required String subtitle, required IconData icon, required bool isDark, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? Colors.white10 : Colors.black12, width: 1), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.04), blurRadius: 15, offset: const Offset(0, 6))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), shape: BoxShape.circle), child: Icon(icon, color: AppColors.primary, size: 24)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : Colors.black87)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500))])),
            Icon(Icons.arrow_forward_ios, color: isDark ? Colors.white54 : AppColors.textHint, size: 16),
          ],
        ),
      ),
    );
  }
}