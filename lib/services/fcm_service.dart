import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final ValueNotifier<int?> pendingTabSwitch = ValueNotifier(null);

  static OverlayState? _overlayState;
  static OverlayEntry? _currentBanner;

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

    _overlayState = Overlay.of(context);

    // App háttérből notification tapra megnyitva
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(message);
    });

    // App killed állapotból notification tapra indítva
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _handleTap(initial);
    }

    // Előtérben érkező értesítések
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      if (message.data['type'] == 'message') {
        _showChatBanner(notification.title ?? 'Új üzenet', notification.body ?? '');
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (notification.body != null) Text(notification.body!),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  static void _showChatBanner(String title, String body) {
    _currentBanner?.remove();
    _currentBanner = null;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _InAppChatBanner(
        title: title,
        body: body,
        onTap: () {
          entry.remove();
          _currentBanner = null;
          pendingTabSwitch.value = 2;
        },
        onDismiss: () {
          entry.remove();
          _currentBanner = null;
        },
      ),
    );

    _currentBanner = entry;
    _overlayState?.insert(entry);

    Future.delayed(const Duration(seconds: 5), () {
      if (_currentBanner == entry) {
        try {
          entry.remove();
        } catch (_) {}
        _currentBanner = null;
      }
    });
  }

  static void _handleTap(RemoteMessage message) {
    if (message.data['type'] == 'message') {
      pendingTabSwitch.value = 2;
    }
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

class _InAppChatBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppChatBanner({
    required this.title,
    required this.body,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppChatBanner> createState() => _InAppChatBannerState();
}

class _InAppChatBannerState extends State<_InAppChatBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _slide,
        child: Material(
          elevation: 10,
          borderRadius: BorderRadius.circular(14),
          shadowColor: Colors.black54,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD32F2F), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: const Icon(Icons.close, color: Colors.white38, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
