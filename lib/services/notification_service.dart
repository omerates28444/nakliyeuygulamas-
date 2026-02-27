import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();
  static final _db = FirebaseFirestore.instance;

  static Future<void> init() async {
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(initSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final n = msg.notification;
      if (n == null) return;

      const androidDetails = AndroidNotificationDetails(
        'default_channel',
        'Genel',
        importance: Importance.max,
        priority: Priority.high,
      );

      await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        n.title,
        n.body,
        const NotificationDetails(android: androidDetails),
      );
    });
  }

  static Future<void> syncTokenToUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final token = await _fcm.getToken();
    if (token == null) return;

    await _db.collection("users").doc(uid).set({
      "extra": {
        "fcmTokens": FieldValue.arrayUnion([token]),
      }
    }, SetOptions(merge: true));
  }
}