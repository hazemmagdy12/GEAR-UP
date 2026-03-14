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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await CacheHelper.init();

  if (CacheHelper.getData(key: 'lang') == null) {
    await CacheHelper.saveData(key: 'lang', value: 'ar');
  }

  await Firebase.initializeApp();

  await Permission.notification.isDenied.then((value) {
    if (value) {
      Permission.notification.request();
    }
  });

  NotificationHelper.init();

  FirebaseMessaging.instance.subscribeToTopic('all_users');

  FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

  Widget startWidget = const SplashScreen();

  runApp(GearUpApp(startWidget: startWidget));
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
      // 🔥 الـ BlocBuilder اللي بيلقط التغيير من السيتينج ويسمعه في التطبيق كله 🔥
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return BlocBuilder<LocaleCubit, Locale>(
            builder: (context, locale) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Gear Up',
                theme: AppTheme.lightTheme.copyWith(
                  textTheme: GoogleFonts.almaraiTextTheme(AppTheme.lightTheme.textTheme),
                ),
                darkTheme: AppTheme.darkTheme.copyWith(
                  textTheme: GoogleFonts.almaraiTextTheme(AppTheme.darkTheme.textTheme).apply(
                    bodyColor: Colors.white,
                    displayColor: Colors.white,
                  ),
                ),
                // 🔥 الربط المباشر مع حالة الـ Cubit 🔥
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