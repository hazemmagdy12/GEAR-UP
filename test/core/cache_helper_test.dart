import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// 🔥 اتأكد إن مسار الـ CacheHelper صح حسب مشروعك
import 'package:gear_up/core/local_storage/cache_helper.dart';

void main() {
  // الدالة دي بتشتغل قبل أي اختبار عشان تجهز الذاكرة الوهمية
  setUp(() async {
    // بنعمل Mock (محاكاة) للـ SharedPreferences عشان منبوظش داتا الموبايل الحقيقي
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();
  });

  // جروب بيضم كل الاختبارات الخاصة بالـ CacheHelper
  group('CacheHelper Tests 🔥', () {

    test('Should save and retrieve String data successfully', () async {
      // 1. Arrange (التجهيز)
      const key = 'test_uid';
      const value = 'user_12345_gear_up';

      // 2. Act (التنفيذ)
      await CacheHelper.saveData(key: key, value: value);
      final result = CacheHelper.getData(key: key);

      // 3. Assert (التأكد من النتيجة)
      expect(result, value); // بنتوقع إن النتيجة اللي رجعت هي هي نفس القيمة
    });

    test('Should delete data successfully', () async {
      // 1. Arrange (التجهيز)
      const key = 'recent_search';
      await CacheHelper.saveData(key: key, value: 'BMW');

      // 2. Act (التنفيذ)
      await CacheHelper.removeData(key: key); // بنمسح الداتا
      final result = CacheHelper.getData(key: key);

      // 3. Assert (التأكد من النتيجة)
      expect(result, null); // بنتوقع إن النتيجة ترجع null بعد المسح
    });

  });
}