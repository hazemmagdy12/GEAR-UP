import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

import 'core/utils/notification_helper.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/cubit/theme_cubit.dart';
import 'core/localization/cubit/locale_cubit.dart';
import 'core/local_storage/cache_helper.dart';
import 'features/auth/cubit/auth_cubit.dart';
import 'features/marketplace/cubit/market_cubit.dart';
import 'features/intro/screens/splash_screen.dart';

// 🔥 دالة معالجة الإشعارات في الخلفية (يجب أن تظل خارج الـ main)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  // 1. التأكد من تهيئة أدوات فلاتر قبل أي عملية أخرى
  WidgetsFlutterBinding.ensureInitialized();

  // 2. تهيئة الكاش واللغة
  await CacheHelper.init();
  if (CacheHelper.getData(key: 'lang') == null) {
    await CacheHelper.saveData(key: 'lang', value: 'ar');
  }

  // 3. تهيئة الفايربيز الأساسي
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 4. إعدادات Firestore (التخزين المحلي للبيانات)
  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  // 🔥 5. استدعاء الصلاحيات والإشعارات في الخلفية (بدون await) لفتح التطبيق فوراً
  //_setupNotificationsAndPermissions();

  // 6. تحديد الشاشة الافتتاحية وتشغيل التطبيق
  Widget startWidget = const SplashScreen();
  runApp(GearUpApp(startWidget: startWidget));
}

// 🔥 دالة مستقلة لإدارة الصلاحيات والإشعارات دون تعطيل رسم الشاشة السوداء
Future<void> _setupNotificationsAndPermissions() async {
  try {
    // طلب صلاحية الإشعارات للأندرويد 13 فما فوق
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    // طلب صلاحيات Firebase Messaging
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // تهيئة المساعد الخاص بالإشعارات والاشتراك في القنوات
    NotificationHelper.init();
    FirebaseMessaging.instance.subscribeToTopic('all_users');

    debugPrint("✅ تم إعداد الإشعارات بنجاح في الخلفية.");
  } catch (e) {
    debugPrint("❌ خطأ في إعداد الإشعارات: $e");
  }
}

class GearUpApp extends StatelessWidget {
  final Widget startWidget;

  const GearUpApp({super.key, required this.startWidget});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (context) => ThemeCubit()),
        BlocProvider(create: (context) => LocaleCubit()),
        BlocProvider(create: (context) => AuthCubit()),
        BlocProvider(create: (context) => MarketCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Gear Up',
                // إعدادات الثيم الفاتح مع الخط العربي
                theme: AppTheme.lightTheme.copyWith(
                  textTheme: GoogleFonts.almaraiTextTheme(AppTheme.lightTheme.textTheme),
                ),
                // إعدادات الثيم الغامق مع الخط العربي
                darkTheme: AppTheme.darkTheme.copyWith(
                  textTheme: GoogleFonts.almaraiTextTheme(AppTheme.darkTheme.textTheme).apply(
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
                  ),
                ),
                themeMode: themeMode,
                locale: locale,
                supportedLocales: const [
                  Locale('en'),
                  Locale('ar'),
                ],
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: startWidget,
              );
            },
          );
        },
      ),
    );
  }
}