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

    // 🔥 3. إنشاء قناة الإشعارات (ضروري جداً لأندرويد 8+) 🔥
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'gear_up_channel',
      'Gear Up Notifications',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. إعدادات الإشعارات المحلية
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);

    // 5. جلب التوكن
    _firebaseMessaging.getToken().then((token) async {
      print("🔥 FCM Token: $token");
      if (token != null) {
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
    });

    // 6. استقبال الإشعارات والأبلكيشن مفتوح
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });
  }

  static void _showLocalNotification(RemoteMessage message) {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'gear_up_channel', // لازم نفس اسم القناة اللي فوق
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
      channelDescription: 'قناة مخصصة لتنبيهات الصيانة بصوت السرينة',
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