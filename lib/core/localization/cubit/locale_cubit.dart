import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../local_storage/cache_helper.dart';

class LocaleCubit extends Cubit<Locale> {
  LocaleCubit() : super(const Locale('ar')) { // الديفولت المبدئي
    _loadLocale();
  }

  void _loadLocale() {
    String? languageCode = CacheHelper.getData(key: 'languageCode');
    if (languageCode != null) {
      emit(Locale(languageCode));
    } else {
      emit(const Locale('ar')); // 🔥 الديفولت لأي مستخدم جديد بقى عربي 🔥
    }
  }

  void changeLanguage(String languageCode) {
    if (state.languageCode != languageCode) {
      CacheHelper.saveData(key: 'languageCode', value: languageCode);
      emit(Locale(languageCode));
    }
  }
}