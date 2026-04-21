import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../local_storage/cache_helper.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("📩 إشعار في الخلفية: ${message.messageId}");
}

class NotificationHelper {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 1. طلب تصريح الإشعارات
    NotificationSettings settings = await _firebaseMessaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ المستخدم وافق على الإشعارات');
    }

    // 2. تفعيل استقبال الإشعارات في الخلفية
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 🔥 3. إنشاء قنوات الإشعارات (الأساسية + السرينة) لأندرويد 8+ 🔥
    const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
      'gear_up_channel',
      'Gear Up Notifications',
      importance: Importance.max,
    );

    const AndroidNotificationChannel sirenChannel = AndroidNotificationChannel(
      'siren_channel_id',
      'Siren Notifications',
      description: 'Maintenance Reminders',
      importance: Importance.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('siren'),
    );

    final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(defaultChannel);
    await androidPlugin?.createNotificationChannel(sirenChannel);

    // 4. إعدادات الإشعارات المحلية
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);

    // 5. جلب التوكن لأول مرة
    _firebaseMessaging.getToken().then((token) => _updateTokenInFirestore(token));

    // 6. تحديث التوكن أوتوماتيك لو جوجل غيرته
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      print("🔄 تم تجديد الـ FCM Token: $newToken");
      _updateTokenInFirestore(newToken);
    });

    // 🔥 7. استقبال الإشعارات والأبلكيشن مفتوح (توجيه ذكي) 🔥
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // لو السيرفر باعت إن ده تذكير صيانة، نشغل السرينة حتى لو الأبلكيشن مفتوح
        if (message.data['type'] == 'reminder') {
          showSirenNotification(
            message.notification!.title ?? 'تنبيه',
            message.notification!.body ?? 'لديك موعد صيانة!',
          );
        } else {
          // أي إشعار تاني (أخبار، ريفيو، مسج) يروح للقناة العادية
          _showLocalNotification(message);
        }
      }
    });
  }

  // دالة مساعدة لتحديث التوكن في الفايربيز
  static Future<void> _updateTokenInFirestore(String? token) async {
    if (token == null) return;
    print("🔥 FCM Token: $token");
    String? uid = CacheHelper.getData(key: 'uid');
    if (uid != null && uid.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {'fcmToken': token},
          SetOptions(merge: true),
        );
      } catch (e) {
        print("❌ خطأ في حفظ التوكن: $e");
      }
    }
  }

  static void _showLocalNotification(RemoteMessage message) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'gear_up_channel',
      'Gear Up Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      message.hashCode,
      message.notification!.title ?? '',
      message.notification!.body ?? '',
      details,
    );
  }

  static void showSirenNotification(String title, String body) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'siren_channel_id',
      'Siren Notifications',
      channelDescription: 'Maintenance Reminders',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('siren'),
      enableVibration: true,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
    );
  }
}