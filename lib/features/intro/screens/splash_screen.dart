import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../../core/theme/colors.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../home/screens/main_layout.dart';
import '../../intro/screens/welcome_screen.dart';
import '../../intro/screens/onboarding_survey_screen.dart';
import '../../auth/screens/email_verification_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAppAndVideo();
  }

  Future<void> _initializeAppAndVideo() async {
    // 1. تجهيز الفيديو
    _videoController = VideoPlayerController.asset('assets/videos/splash_video.mp4');

    try {
      await _videoController.initialize();
      setState(() {
        _isVideoInitialized = true;
      });
      _videoController.play();
    } catch (e) {
      debugPrint("Error loading video: $e");
    }

    // 2. تشغيل مؤقت الفيديو (3 ثواني) وتحميل الداتا في نفس الوقت 🔥
    // 🔥 حماية V2: ضفنا try-catch عشان الأبلكيشن ميعلقش لو مفيش نت
    try {
      await Future.wait([
        _playVideoFor3Seconds(),
        _preloadAppData(),
      ]);
    } catch (e) {
      debugPrint("Splash wait error (Ignored to prevent freeze): $e");
    }

    // 3. التوجيه الذكي للشاشة المناسبة
    await _navigateToNextScreen();
  }

  Future<void> _playVideoFor3Seconds() async {
    await Future.delayed(const Duration(seconds: 3));
  }

  // تحميل الداتا في الخلفية بأمان
  Future<void> _preloadAppData() async {
    try {
      final marketCubit = context.read<MarketCubit>();
      final authCubit = context.read<AuthCubit>();

      final currentUser = FirebaseAuth.instance.currentUser;
      final String? uid = CacheHelper.getData(key: 'uid');

      if (uid != null || currentUser != null) {
        // بنعمل catchError عشان لو النت قاطع ميكسرش الـ Future.wait
        await authCubit.getUserData().catchError((_) {});
      }

      await Future.wait([
        marketCubit.getCars().catchError((_) {}),
        marketCubit.getNews().catchError((_) {}),
      ]);
    } catch (e) {
      debugPrint("Error preloading data: $e");
    }
  }

  // 🔥 العقل المدبر لتوجيه اليوزر (The Smart Router V2) 🔥
  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    User? currentUser = FirebaseAuth.instance.currentUser;
    final String? cachedUid = CacheHelper.getData(key: 'uid');
    final bool isSurveyCompleted = CacheHelper.getData(key: 'survey_completed') ?? false;

    if (currentUser != null) {
      // 🟢 اليوزر مسجل دخول في الفايربيز 🟢

      if (!currentUser.emailVerified) {
        try {
          await currentUser.reload();
          currentUser = FirebaseAuth.instance.currentUser;
        } catch (e) {
          debugPrint("Network error reloading user: $e");
        }
      }

      if (!mounted) return; // 🔥 حماية V2 بعد الـ await

      if (currentUser != null && currentUser.emailVerified) {
        // ✔️ الإيميل متفعل وزي الفل
        if (cachedUid == null) {
          await CacheHelper.saveData(key: 'uid', value: currentUser.uid);
        }

        // 🔥 حل لغم مسح الكاش: بنعتمد على الـ Survey Flag مش الـ UID
        if (!isSurveyCompleted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OnboardingSurveyScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainLayout()));
        }
      } else {
        // ❌ لسه مفعلش الإيميل
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EmailVerificationScreen()));
      }

    } else {
      // 🔴 مفيش يوزر مسجل دخول في الفايربيز أصلاً 🔴

      // 🔥 تأمين فخ الزوار: بنتأكد إنه زائر فعلاً مش داتا وهمية
      if (cachedUid != null && cachedUid.startsWith('guest_')) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainLayout()));
      } else {
        // يوزر جديد لانج
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const WelcomeScreen()));
      }
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _isVideoInitialized
            ? SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _videoController.value.size.width,
              height: _videoController.value.size.height,
              child: VideoPlayer(_videoController),
            ),
          ),
        )
            : const CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}