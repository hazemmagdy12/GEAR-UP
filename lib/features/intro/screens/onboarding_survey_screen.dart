import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/colors.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../../core/localization/app_lang.dart';
import '../../home/screens/main_layout.dart';
import '../../auth/screens/email_verification_screen.dart';

class OnboardingSurveyScreen extends StatefulWidget {
  const OnboardingSurveyScreen({super.key});

  @override
  State<OnboardingSurveyScreen> createState() => _OnboardingSurveyScreenState();
}

class _OnboardingSurveyScreenState extends State<OnboardingSurveyScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  bool? _hasCar;
  String? _carUsageKey; // 🔥 هنحفظ الـ Key بدل النص المترجم
  String? _budgetRangeKey; // 🔥 هنحفظ الـ Key بدل النص المترجم

  bool _isSaving = false;

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
    } else if (_currentPage == 3) {
      // 🔥 أول ما يخلص السؤال الأخير وينتقل للصفحة رقم 4، ابدأ الحفظ أوتوماتيك 🔥
      _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
      _savePreferencesAndFinish();
    } else {
      // لو هو في الصفحة الـ 5 وداس على الزرار (تحسباً لو الحفظ خلص بسرعة)
      _navigateBasedOnVerification();
    }
  }

  void _navigateBasedOnVerification() {
    bool isVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (isVerified) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainLayout()), (route) => false);
    } else {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const EmailVerificationScreen()), (route) => false);
    }
  }

  void _skipSurvey() {
    CacheHelper.saveData(key: 'survey_completed', value: true);
    _navigateBasedOnVerification();
  }

  Future<void> _savePreferencesAndFinish() async {
    setState(() => _isSaving = true);
    String? uid = CacheHelper.getData(key: 'uid') ?? FirebaseAuth.instance.currentUser?.uid;

    // 🔥 هنحفظ القيم الإنجليزية الثابتة أو الـ Keys في الداتابيز عشان الذكاء الاصطناعي يفهمها دايماً 🔥
    String finalUsage = _carUsageKey ?? 'general_use';
    String finalBudget = _budgetRangeKey ?? 'open_budget';

    await CacheHelper.saveData(key: 'survey_completed', value: true);
    await CacheHelper.saveData(key: 'pref_hasCar', value: _hasCar ?? false);
    await CacheHelper.saveData(key: 'pref_carUsage', value: finalUsage);
    await CacheHelper.saveData(key: 'pref_budget', value: finalBudget);

    if (uid != null && uid.isNotEmpty && !uid.startsWith('guest_')) {
      try {
        Map<String, dynamic> prefs = {
          'hasCar': _hasCar ?? false,
          'carUsage': finalUsage,
          'budgetRange': finalBudget,
          'surveyCompletedAt': DateTime.now().toIso8601String(),
        };
        await FirebaseFirestore.instance.collection('users').doc(uid).set({'preferences': prefs}, SetOptions(merge: true))
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        print("Error saving preferences to Firebase: $e");
      }
    }

    if (!mounted) return;
    setState(() => _isSaving = false); // 🔥 وقف اللودينج عشان يظهر زرار الدخول
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_currentPage < 4) // إخفاء زر التخطي في الصفحة الأخيرة
            TextButton(
              onPressed: _skipSurvey,
              child: Text(AppLang.tr(context, 'skip') ?? "تخطي", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontWeight: FontWeight.bold, fontSize: 16)),
            )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Row(
                children: List.generate(5, (index) => Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 6,
                    decoration: BoxDecoration(
                      color: index <= _currentPage ? AppColors.primary : (isDark ? Colors.white10 : Colors.black12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _buildWelcomePage(isDark),
                  _buildCarOwnershipPage(isDark),
                  _buildCarUsagePage(isDark),
                  _buildBudgetPage(isDark),
                  _buildFinalPage(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/logo.png', height: 110),
          const SizedBox(height: 24),

          Text(
            AppLang.tr(context, 'welcome_to') ?? "أهلاً بك في",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),

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
              AppLang.tr(context, 'gear_up') ?? "جير أب",
              style: TextStyle(
                fontSize: 65,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: isDark ? const Color(0xFF64B5F6).withOpacity(0.4) : Colors.black.withOpacity(0.3),
                    offset: Offset(0, isDark ? 0 : 5),
                    blurRadius: isDark ? 12 : 8,
                  )
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  AppLang.tr(context, 'app_subtitle') ?? "تطبيق السيارات الأول المدعوم بالذكاء الاصطناعي",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text("🤖", style: TextStyle(fontSize: 20)),
            ],
          ),

          const SizedBox(height: 40),

          _buildFeatureRow(Icons.auto_awesome, AppLang.tr(context, 'feature_1') ?? "مساعد ذكي للرد على استفساراتك", isDark),
          _buildFeatureRow(Icons.recommend, AppLang.tr(context, 'feature_2') ?? "ترشيحات سيارات متفصلة على مقاسك", isDark),
          _buildFeatureRow(Icons.analytics_outlined, AppLang.tr(context, 'feature_3') ?? "تحليل أسعار ومواصفات دقيقة", isDark),

          const Spacer(),
          _buildNextButton(AppLang.tr(context, 'start_customization') ?? "يلا نبدأ التخصيص", () => _nextPage()),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Row(
        children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: isDark ? AppColors.primary.withOpacity(0.2) : const Color(0xFFE3F2FD),
                  shape: BoxShape.circle
              ),
              child: Icon(icon, color: isDark ? const Color(0xFF64B5F6) : AppColors.primary, size: 22)
          ),
          const SizedBox(width: 16),
          Expanded(
              child: Text(
                  text,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w600
                  )
              )
          ),
        ],
      ),
    );
  }

  Widget _buildCarOwnershipPage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLang.tr(context, 'question_1') ?? "السؤال الأول", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 8),
          Text(AppLang.tr(context, 'q1_title') ?? "هل تمتلك سيارة حالياً؟", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, height: 1.3)),
          const SizedBox(height: 40),
          _buildOptionCard(title: AppLang.tr(context, 'q1_ans_yes') ?? "نعم، أمتلك سيارة", icon: Icons.directions_car_filled_rounded, isSelected: _hasCar == true, isDark: isDark, onTap: () { setState(() => _hasCar = true); _nextPage(); }),
          const SizedBox(height: 16),
          _buildOptionCard(title: AppLang.tr(context, 'q1_ans_no') ?? "لا، أبحث عن سيارة", icon: Icons.search_rounded, isSelected: _hasCar == false, isDark: isDark, onTap: () { setState(() => _hasCar = false); _nextPage(); }),
        ],
      ),
    );
  }

  Widget _buildCarUsagePage(bool isDark) {
    List<Map<String, dynamic>> usages = [
      {'key': 'family', 'titleKey': 'q2_ans_family', 'defaultTitle': 'عائلية ومريحة', 'icon': Icons.family_restroom},
      {'key': 'economy', 'titleKey': 'q2_ans_economy', 'defaultTitle': 'اقتصادية للعمل واليومي', 'icon': Icons.work_outline},
      {'key': 'sport', 'titleKey': 'q2_ans_sport', 'defaultTitle': 'شبابية ورياضية', 'icon': Icons.sports_motorsports_outlined},
      {'key': 'luxury', 'titleKey': 'q2_ans_luxury', 'defaultTitle': 'فخامة ورفاهية', 'icon': Icons.star_border_rounded},
    ];

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLang.tr(context, 'question_2') ?? "السؤال الثاني", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 8),
          Text(AppLang.tr(context, 'q2_title') ?? "ما هو الغرض الأساسي من السيارة؟", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, height: 1.3)),
          const SizedBox(height: 32),
          ...usages.map((u) => Padding(padding: const EdgeInsets.only(bottom: 16.0), child: _buildOptionCard(title: AppLang.tr(context, u['titleKey']) ?? u['defaultTitle'], icon: u['icon'], isSelected: _carUsageKey == u['key'], isDark: isDark, onTap: () { setState(() => _carUsageKey = u['key']); _nextPage(); }))),
        ],
      ),
    );
  }

  Widget _buildBudgetPage(bool isDark) {
    List<Map<String, String>> budgets = [
      {'key': 'under_500k', 'titleKey': 'q3_ans_1', 'default': 'أقل من 500 ألف ج.م'},
      {'key': '500k_to_1m', 'titleKey': 'q3_ans_2', 'default': 'من 500 ألف إلى مليون ج.م'},
      {'key': '1m_to_2m', 'titleKey': 'q3_ans_3', 'default': 'من مليون إلى 2 مليون ج.م'},
      {'key': 'above_2m', 'titleKey': 'q3_ans_4', 'default': 'أكثر من 2 مليون ج.م'}
    ];

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppLang.tr(context, 'question_last') ?? "السؤال الأخير", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 8),
          Text(AppLang.tr(context, 'q3_title') ?? "ما هي ميزانيتك التقريبية؟", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, height: 1.3)),
          const SizedBox(height: 32),
          ...budgets.map((b) => Padding(padding: const EdgeInsets.only(bottom: 16.0), child: _buildOptionCard(title: AppLang.tr(context, b['titleKey']!) ?? b['default']!, icon: Icons.account_balance_wallet_outlined, isSelected: _budgetRangeKey == b['key'], isDark: isDark, onTap: () { setState(() => _budgetRangeKey = b['key']!); _nextPage(); }))),
        ],
      ),
    );
  }

  Widget _buildFinalPage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSaving) ...[
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 24),
            Text(AppLang.tr(context, 'customizing_ai') ?? "جاري تخصيص التطبيق لك بالذكاء الاصطناعي...", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, height: 1.5)),
          ] else ...[
            Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 60)),
            const SizedBox(height: 32),
            Text(AppLang.tr(context, 'ready_to_go') ?? "جاهزين للانطلاق! 🚀", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            Text(AppLang.tr(context, 'prefs_saved_desc') ?? "تم حفظ تفضيلاتك بنجاح، دلوقتي هتشوف العربيات اللي متفصلة على مقاسك بالظبط في الصفحة الرئيسية.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.6, color: isDark ? Colors.white70 : AppColors.textSecondary)),
            const SizedBox(height: 40),
            _buildNextButton(AppLang.tr(context, 'enter_app') ?? "دخول التطبيق", () => _navigateBasedOnVerification()),
          ]
        ],
      ),
    );
  }

  Widget _buildOptionCard({required String title, required IconData icon, required bool isSelected, required bool isDark, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF161E27) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.black12), width: 1.5),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.primary), size: 24),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87)))),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNextButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 5,
          shadowColor: AppColors.primary.withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      ),
    );
  }
}