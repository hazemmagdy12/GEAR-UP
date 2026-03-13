import 'package:shared_preferences/shared_preferences.dart';

class CacheHelper {
  static late SharedPreferences sharedPreferences;

  // الدالة دي بنناديها أول ما الأبلكيشن يفتح عشان نجهز الذاكرة
  static Future<void> init() async {
    sharedPreferences = await SharedPreferences.getInstance();
  }

  // حفظ داتا (سواء كانت String, bool, int, أو List)
  static Future<bool> saveData({required String key, required dynamic value}) async {
    if (value is String) return await sharedPreferences.setString(key, value);
    if (value is int) return await sharedPreferences.setInt(key, value);
    if (value is bool) return await sharedPreferences.setBool(key, value);
    if (value is double) return await sharedPreferences.setDouble(key, value);
    // 🔥 السطر اللي اتضاف عشان يدعم حفظ سجل البحث (List of Strings) 🔥
    if (value is List<String>) return await sharedPreferences.setStringList(key, value);

    return false;
  }

  // قراءة الداتا العادية
  static dynamic getData({required String key}) {
    return sharedPreferences.get(key);
  }

  // 🔥 دالة جديدة اتضافت لقراءة اللستة المخصوصة بتاعة سجل البحث بأمان 🔥
  static List<String>? getStringList({required String key}) {
    return sharedPreferences.getStringList(key);
  }

  // مسح داتا معينة
  static Future<bool> removeData({required String key}) async {
    return await sharedPreferences.remove(key);
  }
}