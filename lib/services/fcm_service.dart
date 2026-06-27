import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> initialize(BuildContext context) async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM engedély megtagadva.');
      return;
    }

    final token = await _messaging.getToken();
    await _saveToken(token);

    _messaging.onTokenRefresh.listen(_saveToken);

    // Előtérben érkező értesítések: SnackBar-ban mutatjuk
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (notification.body != null) Text(notification.body!),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  static Future<void> _saveToken(String? token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || token == null) return;
    try {
      await _firestore.collection('userProfiles').doc(uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FCM token mentési hiba: $e');
    }
  }

  static Future<void> deleteToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _messaging.deleteToken();
    await _firestore
        .collection('userProfiles')
        .doc(uid)
        .update({'fcmToken': FieldValue.delete()});
  }
}
