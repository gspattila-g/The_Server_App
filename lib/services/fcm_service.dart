import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../navigation_key.dart';

class FcmService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final ValueNotifier<int?> pendingTabSwitch = ValueNotifier(null);
  static final ValueNotifier<int?> pendingCommunityTab = ValueNotifier(null);
  static OverlayEntry? _currentBanner;

  // These subscriptions are stored as statics so they are registered exactly
  // once per app process and never accumulate across logins.
  static StreamSubscription<String>? _tokenRefreshSub;
  static StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  static StreamSubscription<RemoteMessage>? _onMessageSub;

  static Future<void> initialize(BuildContext context) async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Always refresh and save the token for the current user on every login.
    final token = await _messaging.getToken();
    await _saveToken(token);

    // App killed állapotból notification tapra indítva
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleTap(initial);

    if (_onMessageSub != null) {
      debugPrint('[FCM] initialize called again — listeners already registered, skipping.');
      return;
    }
    debugPrint('[FCM] Registering listeners for the first time.');

    _tokenRefreshSub = _messaging.onTokenRefresh.listen(_saveToken);

    // App háttérből notification tapra megnyitva
    _onMessageOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // Előtérben érkező értesítések
    _onMessageSub = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;

      // Only chat messages get the banner here — all other notification types
      // (like, friend_request, comment) are handled by the Firestore stream in
      // WelcomePage, which is the authoritative source for foreground snackbars.
      // Showing them here too would duplicate snackbars and cause cross-account
      // delivery when the FCM token is reused across logins on the same device.
      if (message.data['type'] == 'message') {
        _showChatBanner(
          notification.title ?? 'Új üzenet',
          notification.body ?? '',
        );
      }
    });
  }

  static void _showChatBanner(String title, String body) {
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

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
    overlay.insert(entry);

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
    final type = message.data['type'];
    if (type == 'message') {
      pendingTabSwitch.value = 2;
    } else if (type == 'friend_request') {
      pendingCommunityTab.value = 1; // Kérések sub-tab
      pendingTabSwitch.value = 1;    // Community főtab
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
                border:
                    Border.all(color: const Color(0xFFD32F2F), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD32F2F),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.chat, color: Colors.white, size: 18),
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
                    child: const Icon(Icons.close,
                        color: Colors.white38, size: 20),
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
