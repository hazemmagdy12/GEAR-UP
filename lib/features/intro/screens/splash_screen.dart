import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 ضفنا الفايربيز هنا 🔥
import '../../../core/local_storage/cache_helper.dart';
import '../../../core/theme/colors.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../home/screens/main_layout.dart';
import '../../intro/screens/welcome_screen.dart';
import '../../intro/screens/onboarding_survey_screen.dart'; // 🔥 ضفنا شاشة الاستبيان 🔥
import '../../auth/screens/email_verification_screen.dart'; // 🔥 ضفنا شاشة التفعيل 🔥

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
      print("Error loading video: $e");
    }

    // 2. تشغيل مؤقت الفيديو (3 ثواني) وتحميل الداتا في نفس الوقت 🔥
    await Future.wait([
      _playVideoFor3Seconds(),
      _preloadAppData(),
    ]);

    // 3. التوجيه الذكي للشاشة المناسبة
    await _navigateToNextScreen();
  }

  Future<void> _playVideoFor3Seconds() async {
    await Future.delayed(const Duration(seconds: 3));
  }

  // تحميل الداتا في الخلفية
  // تحميل الداتا في الخلفية
  Future<void> _preloadAppData() async {
    final marketCubit = context.read<MarketCubit>();
    final authCubit = context.read<AuthCubit>();

    // 🔥 بنشيك على الفايربيز مش الكاش بس 🔥
    final currentUser = FirebaseAuth.instance.currentUser;
    final String? uid = CacheHelper.getData(key: 'uid');

    if (uid != null || currentUser != null) {
      // الدالة دي بتجيب بيانات اليوزر (اسمه وصورته)
      await authCubit.getUserData();
    }

    await Future.wait([
      // 🔥 الدالة دي بقت بتجيب العربيات وقطع الغيار مع بعض من فايربيز وتوزعهم
      marketCubit.getCars(),

      // الدالة دي بتجيب الأخبار
      marketCubit.getNews(),
    ]);
  }

  // 🔥 العقل المدبر لتوجيه اليوزر (The Smart Router) 🔥
  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    User? currentUser = FirebaseAuth.instance.currentUser;
    final String? cachedUid = CacheHelper.getData(key: 'uid');

    if (currentUser != null) {
      // 🟢 اليوزر مسجل دخول في الفايربيز (حتى لو قفل الأبلكيشن وفتحه) 🟢

      // لو الفايربيز بيقول إنه لسه مفعلش، بنعمل تحديث للبيانات (عشان لو فعله من الجيميل ورجع)
      if (!currentUser.emailVerified) {
        await currentUser.reload();
        currentUser = FirebaseAuth.instance.currentUser;
      }

      if (currentUser != null && currentUser.emailVerified) {
        // ✔️ الإيميل متفعل وزي الفل
        if (cachedUid == null) {
          // لو الـ uid مش في الكاش، معناه إنه لسه مفعل الإيميل دلوقتي ومكملش الاستبيان
          await CacheHelper.saveData(key: 'uid', value: currentUser.uid);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const OnboardingSurveyScreen()));
        } else {
          // يوزر قديم ومخلص كل حاجة، يخش على طول
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainLayout()));
        }
      } else {
        // ❌ اليوزر مسجل دخول بس لسه مفعلش الإيميل! نرميه على شاشة التفعيل
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EmailVerificationScreen()));
      }

    } else {
      // 🔴 مفيش يوزر مسجل دخول في الفايربيز أصلاً 🔴
      if (cachedUid != null) {
        // (حالة استثنائية): لو في يوزر زائر أو مسجل بطريقة تانية
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