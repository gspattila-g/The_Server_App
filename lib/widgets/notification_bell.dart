import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/notification_service.dart';
import '../views/notifications/notifications_page.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  final _notificationService = NotificationService();
  StreamSubscription<User?>? _authSub;
  StreamSubscription<int>? _countSub;
  String? _currentUserId;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId != null) _subscribeToCount(_currentUserId!);

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user?.uid != _currentUserId) {
        _countSub?.cancel();
        setState(() {
          _currentUserId = user?.uid;
          _count = 0;
        });
        if (_currentUserId != null) _subscribeToCount(_currentUserId!);
      }
    });
  }

  void _subscribeToCount(String userId) {
    _countSub = _notificationService
        .getUnreadCountStream(userId)
        .listen((count) {
      if (mounted) setState(() => _count = count);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _countSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) return const SizedBox.shrink();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
        ),
        if (_count > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                _count > 99 ? '99+' : '$_count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
