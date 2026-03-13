import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../local_storage/cache_helper.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit() : super(ThemeMode.system) {
    _loadTheme();
  }

  void _loadTheme() {
    String? savedTheme = CacheHelper.getData(key: 'theme');

    if (savedTheme == 'dark') {
      emit(ThemeMode.dark);
    } else if (savedTheme == 'light') {
      emit(ThemeMode.light);
    } else {
      emit(ThemeMode.system);
    }
  }

  void changeTheme(ThemeMode themeMode) {
    emit(themeMode);
    if (themeMode == ThemeMode.dark) {
      CacheHelper.saveData(key: 'theme', value: 'dark');
    } else if (themeMode == ThemeMode.light) {
      CacheHelper.saveData(key: 'theme', value: 'light');
    } else {
      CacheHelper.saveData(key: 'theme', value: 'system');
    }
  }

  // 🔥 دي الدالة اللي كانت ناقصة عشان الزرار يشتغل صح 🔥
  void toggleTheme() {
    if (state == ThemeMode.light || state == ThemeMode.system) {
      changeTheme(ThemeMode.dark);
    } else {
      changeTheme(ThemeMode.light);
    }
  }
}