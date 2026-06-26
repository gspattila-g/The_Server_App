import 'package:flutter/material.dart';

import '../home/home_page.dart';
import '../profile/profile_page.dart';
import '../community/community_page.dart';
import '../users/users_page.dart';
import '../games/games_page.dart';
import '../settings/settings_page.dart';
import '../more/more_page.dart';

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
    with AutomaticKeepAliveClientMixin {
  int _currentIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomePage(userEmail: widget.email),   // 0
      const CommunityPage(),               // 1
      ProfilePage(email: widget.email),    // 2
      const UsersPage(),                   // 3
      const GamesPage(),                   // 4
      const SettingsPage(),                // 5
    ];
  }

  @override
  bool get wantKeepAlive => true;

  // Maps page index to bottom nav bar item index (3,4,5 → "Több" = 3)
  int get _navBarIndex => _currentIndex <= 2 ? _currentIndex : 3;

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
          setState(() => _currentIndex = 3);
        },
        onGamesSelected: () {
          Navigator.pop(sheetCtx);
          setState(() => _currentIndex = 4);
        },
        onSettingsSelected: () {
          Navigator.pop(sheetCtx);
          setState(() => _currentIndex = 5);
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
          if (index == 3) {
            _showMoreSheet();
          } else {
            setState(() => _currentIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Főoldal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Közösség',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'Több',
          ),
        ],
      ),
    );
  }
}
