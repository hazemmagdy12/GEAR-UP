import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../home/widgets/ai_chat_bottom_sheet.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  int _selectedCategory = 0;

  final Map<String, GlobalKey> _categoryKeys = {
    "General": GlobalKey(), "Features": GlobalKey(), "My Car": GlobalKey(), "Parts": GlobalKey(), "Account": GlobalKey(), "Service": GlobalKey(), "Settings": GlobalKey(),
  };

  void _scrollToCategory(String categoryKey) {
    if (categoryKey == 'all') return;
    String englishCategory = _getEnglishCategoryFromKey(categoryKey);
    final key = _categoryKeys[englishCategory];
    if (key != null && key.currentContext != null) { Scrollable.ensureVisible(key.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut, alignment: 0.1,); }
  }

  String _getEnglishCategoryFromKey(String key) {
    switch (key) { case 'general': return 'General'; case 'features': return 'Features'; case 'my_car': return 'My Car'; case 'parts': return 'Parts'; case 'account_information': return 'Account'; case 'service': return 'Service'; case 'settings': return 'Settings'; default: return 'General'; }
  }

  Future<void> _openWhatsApp() async {
    const phoneNumber = "201288489827";
    final Uri url = Uri.parse("https://wa.me/$phoneNumber");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن فتح واتساب، يرجى التأكد من تثبيته.')));
    }
  }

  Future<void> _makePhoneCall() async {
    final Uri url = Uri.parse("tel:01288489827");
    if (!await launchUrl(url)) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يمكن إجراء المكالمة.')));
    }
  }

  // 🔥 الحل للمشكلة السادسة: دالة إرسال الإيميل القوية 🔥
  Future<void> _sendEmail() async {
    final String email = 'gearup028@gmail.com';
    final String subject = 'Support Request - GEAR UP';

    // بنجرب نفتح تطبيق الـ Gmail مباشرة لو موجود
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );

    try {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لا يوجد تطبيق بريد إلكتروني مثبت على جهازك.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Map<String, String>> categories = [
      {'key': 'all', 'title': AppLang.tr(context, 'all') ?? 'All'}, {'key': 'general', 'title': AppLang.tr(context, 'general') ?? 'General'}, {'key': 'features', 'title': AppLang.tr(context, 'features') ?? 'Features'}, {'key': 'my_car', 'title': AppLang.tr(context, 'my_car') ?? 'My Car'}, {'key': 'account_information', 'title': (AppLang.tr(context, 'account_information') ?? 'Account').split(' ')[0]}, {'key': 'parts', 'title': AppLang.tr(context, 'parts') ?? 'Parts'}, {'key': 'service', 'title': AppLang.tr(context, 'service') ?? 'Service'}, {'key': 'settings', 'title': AppLang.tr(context, 'settings') ?? 'Settings'},
    ];
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: GestureDetector(onTap: () => Navigator.pop(context), child: Container(margin: const EdgeInsets.all(8), decoration: BoxDecoration(border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.3)), borderRadius: BorderRadius.circular(12), color: isDark ? const Color(0xFF161E27).withOpacity(0.8) : Colors.white.withOpacity(0.7),), child: Icon(Icons.arrow_back, size: 24, color: isDark ? Colors.white : AppColors.primary),),),
        title: Text(AppLang.tr(context, 'help_center') ?? 'Help Center', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.w900)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Expanded(child: _buildActionContactCard(icon: Icons.chat_bubble_outline, title: AppLang.tr(context, 'chat_support') ?? 'Chat', isDark: isDark, onTap: _openWhatsApp),),],),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildActionContactCard(icon: Icons.phone_outlined, title: AppLang.tr(context, 'call_us') ?? 'Call Us', isDark: isDark, onTap: _makePhoneCall),),
                const SizedBox(width: 16),
                Expanded(child: _buildActionContactCard(icon: Icons.email_outlined, title: AppLang.tr(context, 'email_us') ?? 'Email Us', isDark: isDark, onTap: _sendEmail),),
              ],
            ),
            const SizedBox(height: 32),
            Text(AppLang.tr(context, 'categories') ?? 'Categories', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, itemCount: categories.length,
                itemBuilder: (context, index) {
                  bool isSelected = _selectedCategory == index;
                  return GestureDetector(
                    onTap: () { setState(() => _selectedCategory = index); _scrollToCategory(categories[index]['key']!); },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(color: isSelected ? AppColors.primary : (isDark ? const Color(0xFF1E2834) : Colors.white), border: Border.all(color: isSelected ? AppColors.primary : (isDark ? Colors.white10 : Colors.black12)), borderRadius: BorderRadius.circular(20), boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],),
                      child: Center(child: Text(categories[index]['title']!, style: TextStyle(color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textSecondary), fontWeight: FontWeight.bold),),),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
            Row(children: [const Icon(Icons.help_outline, color: AppColors.primary, size: 20), const SizedBox(width: 8), Text(AppLang.tr(context, 'faq') ?? 'FAQ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),],),
            const SizedBox(height: 16),
            _buildFaqItem(context: context, isDark: isDark, key: _categoryKeys["General"], category: AppLang.tr(context, 'general') ?? 'General', question: AppLang.tr(context, 'faq_q1') ?? 'Q1', answer: AppLang.tr(context, 'faq_a1') ?? 'A1', isExpanded: true),
            _buildFaqItem(context: context, isDark: isDark, key: _categoryKeys["Features"], category: AppLang.tr(context, 'features') ?? 'Features', question: AppLang.tr(context, 'faq_q2') ?? 'Q2', answer: AppLang.tr(context, 'faq_a2') ?? 'A2'),
            _buildFaqItem(context: context, isDark: isDark, category: AppLang.tr(context, 'features') ?? 'Features', question: AppLang.tr(context, 'faq_q3') ?? 'Q3', answer: AppLang.tr(context, 'faq_a3') ?? 'A3'),
            _buildFaqItem(context: context, isDark: isDark, key: _categoryKeys["My Car"], category: AppLang.tr(context, 'my_car') ?? 'My Car', question: AppLang.tr(context, 'faq_q4') ?? 'Q4', answer: AppLang.tr(context, 'faq_a4') ?? 'A4'),
            _buildFaqItem(context: context, isDark: isDark, key: _categoryKeys["Parts"], category: AppLang.tr(context, 'parts') ?? 'Parts', question: AppLang.tr(context, 'faq_q5') ?? 'Q5', answer: AppLang.tr(context, 'faq_a5') ?? 'A5'),
            _buildFaqItem(context: context, isDark: isDark, key: _categoryKeys["Account"], category: (AppLang.tr(context, 'account_information') ?? 'Account').split(' ')[0], question: AppLang.tr(context, 'faq_q6') ?? 'Q6', answer: AppLang.tr(context, 'faq_a6') ?? 'A6'),
            _buildFaqItem(context: context, isDark: isDark, key: _categoryKeys["Service"], category: AppLang.tr(context, 'service') ?? 'Service', question: AppLang.tr(context, 'faq_q7') ?? 'Q7', answer: AppLang.tr(context, 'faq_a7') ?? 'A7'),
            _buildFaqItem(context: context, isDark: isDark, key: _categoryKeys["Settings"], category: AppLang.tr(context, 'settings') ?? 'Settings', question: AppLang.tr(context, 'faq_q8') ?? 'Q8', answer: AppLang.tr(context, 'faq_a8') ?? 'A8'),
            _buildFaqItem(context: context, isDark: isDark, category: AppLang.tr(context, 'features') ?? 'Features', question: AppLang.tr(context, 'faq_q9') ?? 'Q9', answer: AppLang.tr(context, 'faq_a9') ?? 'A9'),
            _buildFaqItem(context: context, isDark: isDark, category: (AppLang.tr(context, 'account_information') ?? 'Account').split(' ')[0], question: AppLang.tr(context, 'faq_q10') ?? 'Q10', answer: AppLang.tr(context, 'faq_a10') ?? 'A10'),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () { showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => const AiChatBottomSheet(),); },
        backgroundColor: AppColors.primary, elevation: 8, shape: const CircleBorder(), child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildActionContactCard({required IconData icon, required String title, required bool isDark, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.02), blurRadius: 10, offset: const Offset(0, 4))],),
        child: Column(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle,), child: Icon(icon, color: AppColors.primary),), const SizedBox(height: 12), Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),],),
      ),
    );
  }

  Widget _buildFaqItem({required BuildContext context, required bool isDark, Key? key, required String category, required String question, required String answer, bool isExpanded = false}) {
    return Container(
      key: key, margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF161E27) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.white10 : Colors.black12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.1 : 0.02), blurRadius: 8, offset: const Offset(0, 4))],),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isExpanded, tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), iconColor: isDark ? Colors.white : Colors.black, collapsedIconColor: isDark ? Colors.white70 : Colors.black87,
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8),), child: Text(category, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w900)),), const SizedBox(height: 10), Text(question, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),],),
          children: [Padding(padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16), child: Text(answer, style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, height: 1.6, fontSize: 14)),),],
        ),
      ),
    );
  }
}