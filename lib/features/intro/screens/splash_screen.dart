import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/local_storage/cache_helper.dart';
import '../../../core/theme/colors.dart';
import '../../marketplace/cubit/market_cubit.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../home/screens/main_layout.dart';
import '../../intro/screens/welcome_screen.dart';

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
      _playVideoFor3Seconds(), // ⏱️ خليناها 3 ثواني هنا
      _preloadAppData(),
    ]);

    // 3. التوجيه للشاشة المناسبة
    _navigateToNextScreen();
  }

  // ⏱️ الدالة اتعدلت لـ 3 ثواني
  Future<void> _playVideoFor3Seconds() async {
    await Future.delayed(const Duration(seconds: 3));
  }

  // تحميل الداتا في الخلفية
  Future<void> _preloadAppData() async {
    final marketCubit = context.read<MarketCubit>();
    final authCubit = context.read<AuthCubit>();
    final String? uid = CacheHelper.getData(key: 'uid');

    if (uid != null) {
      await authCubit.getUserData();
    }

    await Future.wait([
      marketCubit.getCars(),
      marketCubit.getSpareParts(),
      marketCubit.getNews(),
    ]);
  }

  void _navigateToNextScreen() {
    if (!mounted) return;

    final String? uid = CacheHelper.getData(key: 'uid');

    if (uid != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // إجبار الشاشة إنها تكون بيضاء دايماً وتجاهل الدارك مود عشان الفيديو يندمج
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _isVideoInitialized
            ? SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain, // بيحافظ على أبعاد الفيديو
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