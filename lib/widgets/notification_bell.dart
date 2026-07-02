import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/notification.dart';
import '../navigation_key.dart';
import '../services/notification_service.dart';
import '../views/notifications/notifications_page.dart';

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  // Shared across all NotificationBell instances to prevent duplicate snackbars
  // from IndexedStack keeping all tab pages alive simultaneously.
  static final Set<String> _globalShownIds = {};
  static String? _globalActiveUid;

  final _notificationService = NotificationService();
  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<AppNotification>>? _notifSub;
  String? _currentUserId;
  int _count = 0;
  Set<String> _seenIds = {};
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId != null) _subscribeToNotifications(_currentUserId!);

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      if (user?.uid != _currentUserId) {
        _notifSub?.cancel();
        setState(() {
          _currentUserId = user?.uid;
          _count = 0;
          _seenIds = {};
          _initialLoadDone = false;
        });
        if (_currentUserId != null) _subscribeToNotifications(_currentUserId!);
      }
    });
  }

  void _subscribeToNotifications(String userId) {
    // When switching to a different account, clear the global dedup set
    if (_globalActiveUid != userId) {
      _globalShownIds.clear();
      _globalActiveUid = userId;
    }

    _notifSub = _notificationService
        .getNotificationsForUser(userId)
        .listen((notifications) {
      if (!mounted) return;

      final unread = notifications.where((n) => !n.isRead).toList();
      final newCount = unread.length;

      if (!_initialLoadDone) {
        // Accumulate IDs across multiple initial emissions (handles Firestore
        // sending an empty cache snapshot before the real server snapshot).
        _seenIds = {
          ..._seenIds,
          ...notifications.map((n) => n.id ?? '').where((id) => id.isNotEmpty),
        };
        if (notifications.isNotEmpty) _initialLoadDone = true;
        setState(() => _count = newCount);
        return;
      }

      final newNotifs = notifications
          .where((n) => !_seenIds.contains(n.id ?? ''))
          .toList();

      for (final notif in newNotifs) {
        final id = notif.id ?? '';
        if (id.isNotEmpty && !_globalShownIds.contains(id)) {
          _globalShownIds.add(id);
          _showSnackbar(notif);
          break;
        }
      }

      _seenIds = notifications.map((n) => n.id ?? '').toSet();
      setState(() => _count = newCount);
    }, onError: (_) {});
  }

  void _showSnackbar(AppNotification notification) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    final icons = {
      'friend_request': Icons.person_add,
      'like': Icons.favorite,
      'comment': Icons.comment,
    };
    final icon = icons[notification.type] ?? Icons.notifications;

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(notification.message)),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _notifSub?.cancel();
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
