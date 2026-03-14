import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// استدعاء ملفات المشروع بتاعتك (اتأكد من المسارات لو فيها حاجة مختلفة)
import 'package:gear_up/features/auth/cubit/auth_cubit.dart';
import 'package:gear_up/features/auth/cubit/auth_state.dart';
import 'package:gear_up/core/local_storage/cache_helper.dart';

// ==========================================
// 🔥 1. تجهيز الكلاسات الكدابة (Mocks) 🔥
// ==========================================
class MockFirebaseAuth extends Mock implements FirebaseAuth {}
class MockUserCredential extends Mock implements UserCredential {}
class MockUser extends Mock implements User {}

void main() {
  late AuthCubit authCubit;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  // الدالة دي بتشتغل قبل كل اختبار عشان تجهز الدنيا
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // محاكاة للـ CacheHelper عشان ميكراشش وهو بيقرا/بيكتب
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();

    // تجهيز الكائنات الكدابة
    mockFirebaseAuth = MockFirebaseAuth();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    // 💡 ملحوظة: في الكود بتاعك الـ AuthCubit بيعمل FirebaseAuth.instance جواه،
    // في الـ Testing المتقدم بنمرر الـ auth في الـ Constructor، بس بما إننا بنختبر اللوجيك
    // فإحنا هنختبر الحالات (States) بشكل مباشر.
    authCubit = AuthCubit();
  });

  // تنظيف الرامات بعد الاختبار
  tearDown(() {
    authCubit.close();
  });

  // ==========================================
// 🔥 2. بدء الاختبارات (Test Cases) 🔥
// ==========================================
  group('🧠 Auth Cubit Tests 🧠', () {

    // الاختبار الأول: الحالة الافتراضية
    test('Initial state should be AuthInitial or GetUserLoading (due to constructor)', () {
      // بما إنك بتستدعي getUserData() في الـ Constructor، فالحالة ممكن تتغير فوراً للتحميل
      expect(
          authCubit.state is AuthInitial || authCubit.state is GetUserLoading,
          true
      );
    });

    // الاختبار التاني: اختبار دالة اللوجين (محاكاة انبعاث الحالات)
    // هنا بنختبر إن الـ Cubit بيطلع حالة Loading وبعدين Error لو الباسورد غلط
    blocTest<AuthCubit, AuthState>(
      'emits [AuthLoading, AuthError] when login fails with wrong credentials',
      build: () => authCubit,
      // بنعمل محاكاة إن الفايربيز ضرب إيرور، فالـ Cubit لازم يمسك الإيرور
      act: (cubit) async {
        // بما إن الفايربيز متوصل جوه الكلاس، هننادي الدالة ونتوقع إنها تجيب إيرور (لأن مفيش فايربيز شغال بجد في التيست)
        await cubit.login(email: 'wrong@mail.com', password: 'wrong_password');
      },
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(), // متوقعين يطلع إيرور "البريد الإلكتروني أو كلمة المرور غير صحيحة"
      ],
    );

    // الاختبار التالت: اختبار رفع الصورة
    blocTest<AuthCubit, AuthState>(
      'emits [ProfileImagePickedError] when picking image fails in test environment',
      build: () => authCubit,
      act: (cubit) => cubit.pickProfileImage(),
      // في بيئة الاختبار مفيش معرض صور (Gallery)، فالمتوقع يطلع Error
      expect: () => [
        isA<ProfileImagePickedError>(),
      ],
    );

    // الاختبار الرابع: اختبار تسجيل الخروج (مسح الذاكرة)
    blocTest<AuthCubit, AuthState>(
      'emits [AuthInitial] after logout',
      build: () => authCubit,
      act: (cubit) async {
        // بنحط قيمة في الـ Cache الأول
        await CacheHelper.saveData(key: 'uid', value: '12345');
        // بننادي دالة الخروج (متوقع تضرب إيرور عشان مفيش فايربيز، بس هنجرب اللوجيك)
        try {
          await cubit.logout();
        } catch (_) {}
      },
      // الـ Cubit بيبعت AuthInitial في آخر دالة logout
      expect: () => [
        isA<AuthInitial>(),
      ],
    );
  });
}