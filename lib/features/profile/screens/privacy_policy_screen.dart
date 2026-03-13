import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../home/widgets/ai_chat_bottom_sheet.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 🔥 توحيد لون الخلفية الأساسية للدارك واللايت مود 🔥
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFF4F7FA);

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
              // 🔥 توحيد لون زرار الرجوع 🔥
              border: Border.all(color: isDark ? Colors.white10 : AppColors.primary.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(12),
              color: isDark ? const Color(0xFF161E27).withOpacity(0.8) : Colors.white.withOpacity(0.7),
            ),
            child: Icon(Icons.arrow_back, size: 24, color: isDark ? Colors.white : AppColors.primary),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLang.tr(context, 'privacy_policy_title') ?? 'Privacy Policy', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            Text(AppLang.tr(context, 'last_updated') ?? 'Last Updated: March 2026', style: TextStyle(color: isDark ? Colors.white70 : AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 32),

            _buildSectionTitle(AppLang.tr(context, 'pp_sec1_title') ?? '1. Information We Collect'),
            _buildParagraph(AppLang.tr(context, 'pp_sec1_p1') ?? 'We collect information you provide directly to us.', isDark),
            _buildParagraph(AppLang.tr(context, 'pp_sec1_p2') ?? 'This includes account details, listings, and usage data.', isDark),
            const SizedBox(height: 24),

            _buildSectionTitle(AppLang.tr(context, 'pp_sec2_title') ?? '2. How We Use Information'),
            _buildParagraph(AppLang.tr(context, 'pp_sec2_p1') ?? 'We use the information we collect to:', isDark),
            _buildBulletPoint(AppLang.tr(context, 'pp_sec2_b1') ?? 'Provide, maintain, and improve our services.', isDark),
            _buildBulletPoint(AppLang.tr(context, 'pp_sec2_b2') ?? 'Process transactions and send related information.', isDark),
            _buildBulletPoint(AppLang.tr(context, 'pp_sec2_b3') ?? 'Send technical notices, updates, and support messages.', isDark),
            _buildBulletPoint(AppLang.tr(context, 'pp_sec2_b4') ?? 'Respond to your comments and questions.', isDark),
            _buildBulletPoint(AppLang.tr(context, 'pp_sec2_b5') ?? 'Analyze trends and usage in connection with our services.', isDark),
            _buildBulletPoint(AppLang.tr(context, 'pp_sec2_b6') ?? 'Personalize and improve the services.', isDark),
            const SizedBox(height: 24),

            _buildSectionTitle(AppLang.tr(context, 'pp_sec3_title') ?? '3. Information Sharing'),
            _buildParagraph(AppLang.tr(context, 'pp_sec3_p1') ?? 'We do not share your personal information with third parties except as described in this privacy policy.', isDark),
            const SizedBox(height: 24),

            _buildSectionTitle(AppLang.tr(context, 'pp_sec4_title') ?? '4. Data Security'),
            _buildParagraph(AppLang.tr(context, 'pp_sec4_p1') ?? 'We take reasonable measures to help protect information about you from loss, theft, misuse, and unauthorized access.', isDark),
            const SizedBox(height: 24),

            _buildSectionTitle(AppLang.tr(context, 'pp_sec5_title') ?? '5. Your Choices'),
            _buildParagraph(AppLang.tr(context, 'pp_sec5_p1') ?? 'You have several choices regarding the use of your information:', isDark),
            _buildBulletPoint(AppLang.tr(context, 'pp_sec5_b1') ?? 'You may update or correct your account information.', isDark),
            _buildBulletPoint(AppLang.tr(context, 'pp_sec5_b2') ?? 'You may opt out of promotional communications.', isDark),
            _buildBulletPoint(AppLang.tr(context, 'pp_sec5_b3') ?? 'You may request deletion of your account.', isDark),
            _buildBulletPoint(AppLang.tr(context, 'pp_sec5_b4') ?? 'You may manage cookie preferences.', isDark),
            const SizedBox(height: 24),

            _buildSectionTitle(AppLang.tr(context, 'pp_sec6_title') ?? '6. Changes to this Policy'),
            _buildParagraph(AppLang.tr(context, 'pp_sec6_p1') ?? 'We may change this privacy policy from time to time. If we make changes, we will notify you by revising the date at the top of the policy.', isDark),
            const SizedBox(height: 24),

            _buildSectionTitle(AppLang.tr(context, 'pp_sec7_title') ?? '7. Contact Us'),
            _buildParagraph(AppLang.tr(context, 'pp_sec7_p1') ?? 'If you have any questions about this privacy policy, please contact us at support@gearup.com.', isDark),
            const SizedBox(height: 24),

            _buildSectionTitle(AppLang.tr(context, 'pp_sec8_title') ?? '8. Consent'),
            _buildParagraph(AppLang.tr(context, 'pp_sec8_p1') ?? 'By using our app, you hereby consent to our Privacy Policy and agree to its terms.', isDark),

            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AiChatBottomSheet(),
          );
        },
        backgroundColor: AppColors.primary,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
      ),
    );
  }

  Widget _buildParagraph(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : AppColors.textSecondary, height: 1.6),
      ),
    );
  }

  Widget _buildBulletPoint(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6.0, right: 8.0),
            child: Icon(Icons.circle, size: 6, color: isDark ? Colors.white54 : AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: isDark ? Colors.white70 : AppColors.textSecondary, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}