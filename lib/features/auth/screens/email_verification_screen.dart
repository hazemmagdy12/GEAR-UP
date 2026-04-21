import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';
import '../../../core/localization/app_lang.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../intro/screens/onboarding_survey_screen.dart';
import 'login_screen.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool isEmailVerified = false;
  Timer? timer;
  bool _canResend = true;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;

    if (!isEmailVerified) {
      timer = Timer.periodic(const Duration(seconds: 3), (_) => checkEmailVerified());
    }
  }

  Future<void> checkEmailVerified() async {
    // 🔥 حماية من الكراش: نتأكد إن الشاشة لسه مفتوحة قبل ما نكمل
    if (!mounted) return;

    await FirebaseAuth.instance.currentUser?.reload();

    // 🔥 حماية تانية: بعد ما الـ reload يخلص (لأنه Async)
    if (!mounted) return;

    setState(() {
      isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    });

    if (isEmailVerified) {
      timer?.cancel();
      await CacheHelper.saveData(key: 'uid', value: FirebaseAuth.instance.currentUser!.uid);

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingSurveyScreen()),
              (route) => false,
        );
      }
    }
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;

    final localPart = parts[0];
    final domainPart = parts[1];

    String maskedLocal;
    if (localPart.length <= 2) {
      maskedLocal = '*' * localPart.length;
    } else {
      maskedLocal = '${localPart[0]}${'*' * (localPart.length - 2)}${localPart[localPart.length - 1]}';
    }

    final domainSegments = domainPart.split('.');
    String maskedDomain;
    if (domainSegments.length >= 2) {
      final mainDomain = domainSegments[0];
      final extension = domainSegments.sublist(1).join('.');
      if (mainDomain.length <= 1) {
        maskedDomain = '$mainDomain.$extension';
      } else {
        maskedDomain = '${mainDomain[0]}${'*' * (mainDomain.length - 1)}.$extension';
      }
    } else {
      maskedDomain = domainPart;
    }

    return '$maskedLocal@$maskedDomain';
  }

  void _startCooldown() {
    setState(() {
      _canResend = false;
      _resendCooldown = 60;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) {
        t.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  void _openEmailApp() async {
    final Uri gmailWebUrl = Uri.parse('https://mail.google.com');
    final Uri iosGmailAppUrl = Uri.parse('googlegmail://');

    try {
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        if (await canLaunchUrl(iosGmailAppUrl)) {
          await launchUrl(iosGmailAppUrl, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(gmailWebUrl, mode: LaunchMode.externalApplication);
        }
      } else {
        await launchUrl(gmailWebUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLang.tr(context, 'no_email_app') ?? 'حدث خطأ أثناء فتح البريد الإلكتروني.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color screenBgColor = isDark ? const Color(0xFF0A0F14) : const Color(0xFFE3F2FD);

    final String rawEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    final String maskedEmail = _maskEmail(rawEmail);

    return Scaffold(
      backgroundColor: screenBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () async {
            // 🔥 تنظيف كامل لو اليوزر قرر يرجع وميكملش 🔥
            timer?.cancel();
            await FirebaseAuth.instance.signOut();
            await CacheHelper.clearAllDataExcept();
            if (context.mounted) {
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161E27) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
                ),
                child: const Icon(Icons.mark_email_unread_outlined, size: 80, color: AppColors.primary),
              ),
              const SizedBox(height: 32),
              Text(
                AppLang.tr(context, 'verify_email_title') ?? "تحقق من بريدك الإلكتروني",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                AppLang.tr(context, 'verify_email_sent_to') ?? "لقد أرسلنا رابط التحقق إلى:",
                style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  maskedEmail,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),

              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2416) : const Color(0xFFFFF9E6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFFFFB74D).withOpacity(0.3) : const Color(0xFFF39C12).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFF39C12), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        AppLang.tr(context, 'check_spam_hint') ?? "لو مش لاقي الإيميل، فتش في مجلد الـ Spam أو Junk",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFFFB74D) : const Color(0xFF8B5E00),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openEmailApp,
                  icon: const Icon(Icons.mail_outline, color: Colors.white),
                  label: Text(
                    AppLang.tr(context, 'open_mail_app') ?? "فتح تطبيق الإيميل",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                AppLang.tr(context, 'waiting_for_verification') ?? "في انتظار التحقق...",
                style: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _canResend
                      ? () async {
                    try {
                      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                      _startCooldown();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLang.tr(context, 'link_resent_success') ?? 'تم إعادة إرسال الرابط بنجاح'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(AppLang.tr(context, 'wait_before_resending') ?? 'برجاء الانتظار قليلاً قبل إعادة الإرسال'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: _canResend ? AppColors.primary : Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _canResend
                        ? (AppLang.tr(context, 'resend_link') ?? "إعادة إرسال الرابط")
                        : "${AppLang.tr(context, 'resend_after') ?? 'إعادة الإرسال بعد'} $_resendCooldown ${AppLang.tr(context, 'seconds') ?? 'ثانية'}",
                    style: TextStyle(
                      color: _canResend ? AppColors.primary : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}