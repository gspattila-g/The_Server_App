import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/fcm_service.dart';
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

  late final List<Widget> _pages;
  // UID-t initState-ben tároljuk, hogy dispose()-ban is elérhető legyen
  // akkor is, ha a Firebase Auth már kijelentkeztette a usert
  String? _uid;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FcmService.initialize(context);
      if (_uid != null) _profileService.setStatus(_uid!, 'online');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_uid != null) _profileService.setStatus(_uid!, 'offline');
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = _uid;
    if (uid == null) return;
    if (state == AppLifecycleState.resumed) {
      _profileService.setStatus(uid, 'online');
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _profileService.setStatus(uid, 'offline');
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
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
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
