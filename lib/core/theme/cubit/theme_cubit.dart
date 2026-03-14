import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../local_storage/cache_helper.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  // 🔥 خلينا الديفولت لايت عشان السويتش ميهنجش لو مفيش حاجة متسجلة
  ThemeCubit() : super(ThemeMode.light) {
    _loadTheme();
  }

  void _loadTheme() {
    String? savedTheme = CacheHelper.getData(key: 'theme');

    if (savedTheme == 'dark') {
      emit(ThemeMode.dark);
    } else {
      emit(ThemeMode.light);
    }
  }

  void changeTheme(ThemeMode themeMode) {
    emit(themeMode);
    if (themeMode == ThemeMode.dark) {
      CacheHelper.saveData(key: 'theme', value: 'dark');
    } else {
      CacheHelper.saveData(key: 'theme', value: 'light');
    }
  }

  // 🔥 الدالة المظبوطة اللي زرار السيتينج بينادي عليها 🔥
  void toggleTheme() {
    if (state == ThemeMode.light) {
      changeTheme(ThemeMode.dark);
    } else {
      changeTheme(ThemeMode.light);
    }
  }
}