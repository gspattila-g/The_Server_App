import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/notification.dart';
import '../../navigation_key.dart';
import '../../services/fcm_service.dart';
import '../../services/notification_service.dart';
import '../../services/presence_service.dart';
import '../../services/profile_service.dart';
import '../../services/chat_service.dart';
import '../home/home_page.dart';
import '../profile/profile_page.dart';
import '../community/community_page.dart';
import '../users/users_page.dart';
import '../games/games_page.dart';
import '../settings/settings_page.dart';
import '../more/more_page.dart';
import '../chat/chat_list_page.dart';

class WelcomePage extends StatefulWidget {
  final String email;

  const WelcomePage({
    super.key,
    required this.email,
  });

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  final _profileService = ProfileService();
  final _chatService = ChatService();
  final _notificationService = NotificationService();

  late final List<Widget> _pages;
  String? _uid;

  StreamSubscription<List<AppNotification>>? _notifSub;
  Set<String> _seenNotifIds = {};
  DateTime? _subscribeTime;

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _pages = [
      HomePage(userEmail: widget.email),
      const CommunityPage(),
      const ChatListPage(),
      ProfilePage(email: widget.email),
      const UsersPage(),
      const GamesPage(),
      const SettingsPage(),
    ];
    WidgetsBinding.instance.addObserver(this);
    FcmService.pendingTabSwitch.addListener(_onPendingTabSwitch);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService.initialize(context);
      if (_uid != null) {
        PresenceService.initialize(_uid!);
        _subscribeToNotifications(_uid!);
      }
    });
  }

  void _subscribeToNotifications(String uid) {
    _notifSub?.cancel();
    _seenNotifIds = {};
    // Record when this subscription started — only notifications created AFTER
    // this moment are eligible to show a snackbar. This reliably suppresses all
    // pre-existing notifications regardless of how many Firestore events fire
    // during initial load.
    _subscribeTime = DateTime.now();

    debugPrint('[NOTIF] Subscribing for uid=$uid at ${_subscribeTime}');

    _notifSub = _notificationService
        .getNotificationsForUser(uid)
        .listen((notifications) {
      if (!mounted) return;

      debugPrint('[NOTIF] Stream event: ${notifications.length} total notifications');

      final genuinelyNew = notifications.where((n) {
        if (_seenNotifIds.contains(n.id ?? '')) return false;
        // Must have been created after we started listening
        return n.timestamp.toDate().isAfter(_subscribeTime!);
      }).toList();

      debugPrint('[NOTIF] Genuinely new: ${genuinelyNew.length}');
      for (final n in genuinelyNew) {
        debugPrint('[NOTIF]   NEW id=${n.id} type=${n.type} ts=${n.timestamp.toDate()}');
      }

      if (genuinelyNew.isNotEmpty) _showNotifSnackbar(genuinelyNew.first);

      _seenNotifIds = notifications.map((n) => n.id ?? '').toSet();
    }, onError: (_) {});
  }

  void _showNotifSnackbar(AppNotification notification) {
    debugPrint('[NOTIF] SHOWING SNACKBAR: ${notification.message}');
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

  void _onPendingTabSwitch() {
    final tab = FcmService.pendingTabSwitch.value;
    if (tab != null && mounted) {
      setState(() => _currentIndex = tab);
      FcmService.pendingTabSwitch.value = null;
    }
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    FcmService.pendingTabSwitch.removeListener(_onPendingTabSwitch);
    if (_uid != null) PresenceService.setOffline(_uid!);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = _uid;
    if (uid == null) return;
    if (state == AppLifecycleState.resumed) {
      PresenceService.initialize(uid);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      PresenceService.setStatus(uid, 'offline');
    }
  }

  @override
  bool get wantKeepAlive => true;

  int get _navBarIndex => _currentIndex <= 3 ? _currentIndex : 4;

  void _showMoreSheet() {
    final ctx = context;
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => MorePage(
        onUsersSelected: () {
          Navigator.pop(sheetCtx);
          setState(() => _currentIndex = 4);
        },
        onGamesSelected: () {
          Navigator.pop(sheetCtx);
          setState(() => _currentIndex = 5);
        },
        onSettingsSelected: () {
          Navigator.pop(sheetCtx);
          setState(() => _currentIndex = 6);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navBarIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 4) {
            _showMoreSheet();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Főoldal'),
          const BottomNavigationBarItem(icon: Icon(Icons.people_alt), label: 'Barátok'),
          BottomNavigationBarItem(
            label: 'Üzenetek',
            icon: _uid != null
                ? StreamBuilder<int>(
                    stream: _chatService.getTotalUnreadStream(_uid!),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      return Badge(
                        isLabelVisible: count > 0,
                        label: Text('$count'),
                        child: const Icon(Icons.chat),
                      );
                    },
                  )
                : const Icon(Icons.chat),
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
          const BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'Több'),
        ],
      ),
    );
  }
}
