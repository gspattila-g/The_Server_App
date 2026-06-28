import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore importálása
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth a jelenlegi felhasználó UID-jének lekérdezéséhez

import '../../models/user_profile.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/status_dot.dart';
import '../../models/game.dart';
import '../../services/chat_service.dart';
import '../../services/game_service.dart';
import '../chat/chat_page.dart';
import '../users/user_view_page.dart';

/// Egy oldal, amely listázza az összes felhasználót az alkalmazásban (a jelenlegi kivételével).
///
/// Lehetővé teszi más felhasználók profiljainak megtekintését vagy barátsági
/// kérések küldését a jövőben. Az adatokat valós időben a Firebase Firestore-ból streameli.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  // A Firestore adatbázis példánya.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // A jelenlegi bejelentkezett Firebase felhasználó UID-je.
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Szövegvezérlő a felhasználók keresőmezőjéhez.
  final TextEditingController _searchController = TextEditingController();
  // A felhasználók keresési lekérdezése.
  String _searchQuery = '';

  // GameService példány a játékok lekéréséhez.
  final GameService _gameService = GameService();
  // A jelenlegi felhasználó játékainak listája.
  List<Game> _currentUserGames = [];

  // Szűrő kapcsoló állapota: csak a közös játékokkal rendelkező felhasználókat mutatjuk.
  bool _showCommonGamesOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadCurrentUserGames(); // Jelenlegi felhasználó játékainak betöltése
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // Betölti a jelenlegi felhasználó játékait a stream-ből.
  void _loadCurrentUserGames() {
    if (_currentUserId != null) {
      _gameService.getGamesStreamForUser(_currentUserId!).listen((games) {
        setState(() {
          _currentUserGames = games;
        });
      });
    }
  }

  // A keresőmező tartalmának változásakor hívódik meg.
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  // Segédmetódus a barátság státuszának streameléséhez két felhasználó között
  Stream<String> _getFriendshipStatusStream(String otherUserId) {
    if (_currentUserId == null || otherUserId == _currentUserId) {
      return Stream.value('self'); // Saját profil vagy érvénytelen ID
    }

    // Figyeljük a barátsági kéréseket, ahol az egyik fél mi vagyunk, a másik a megtekintett felhasználó
    return _firestore
        .collection('friendRequests')
        .where('senderId', whereIn: [_currentUserId, otherUserId])
        .where('receiverId', whereIn: [_currentUserId, otherUserId])
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        // Nincs aktív kérés vagy elfogadott barátság közöttük
        return 'none';
      } else {
        final doc = snapshot.docs.first;
        final data = doc.data();
        final status = data['status'] as String;
        final senderId = data['senderId'] as String;

        if (status == 'accepted') {
          return 'friends';
        } else if (status == 'pending') {
          if (senderId == _currentUserId) {
            return 'sent'; // Mi küldtük a kérést
          } else {
            return 'received'; // Mi kaptuk a kérést
          }
        }
        return 'none'; // Valamilyen ismeretlen státusz
      }
    });
  }

  /// Barátsági kérés elküldése.
  Future<void> _sendFriendRequest(String receiverId) async {
    if (_currentUserId == null) return;

    try {
      final existingRequests = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: _currentUserId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequests.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Már küldtél barátsági kérést ennek a felhasználónak.')),
        );
        return;
      }

      final reversedRequests = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: receiverId)
          .where('receiverId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (reversedRequests.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ez a felhasználó már küldött neked barátsági kérést. Kérlek, fogadd el a Közösség oldalon.')),
        );
        return;
      }

      await _firestore.collection('friendRequests').add({
        'senderId': _currentUserId,
        'receiverId': receiverId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barátsági kérés elküldve!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba a kérés küldésekor: $e')),
      );
    }
  }

  /// Barátsági kérés elfogadása.
  Future<void> _acceptFriendRequest(String senderId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final querySnapshot = await _firestore
            .collection('friendRequests')
            .where('senderId', isEqualTo: senderId)
            .where('receiverId', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'pending')
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw Exception('A barátsági kérés nem található vagy már nem függőben lévő.');
        }

        final requestDocRef = querySnapshot.docs.first.reference;
        transaction.update(requestDocRef, {'status': 'accepted'});

        final currentUserFriendsRef = _firestore.collection('friends').doc(_currentUserId);
        transaction.set(
          currentUserFriendsRef,
          {
            'friendIds': FieldValue.arrayUnion([senderId])
          },
          SetOptions(merge: true),
        );

        final otherUserFriendsRef = _firestore.collection('friends').doc(senderId);
        transaction.set(
          otherUserFriendsRef,
          {
            'friendIds': FieldValue.arrayUnion([_currentUserId])
          },
          SetOptions(merge: true),
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barátsági kérés elfogadva!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba a kérés elfogadásakor: $e')),
      );
    }
  }

  /// Barátsági kérés elutasítása.
  Future<void> _rejectFriendRequest(String senderId) async {
    if (_currentUserId == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: senderId)
          .where('receiverId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('A barátsági kérés nem található.');
      }

      final requestDocRef = querySnapshot.docs.first.reference;
      await requestDocRef.update({'status': 'rejected'});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barátsági kérés elutasítva.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba a kérés elutasításakor: $e')),
      );
    }
  }

  /// Elküldött barátsági kérés visszavonása.
  Future<void> _cancelFriendRequest(String receiverId) async {
    if (_currentUserId == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: _currentUserId)
          .where('receiverId', isEqualTo: receiverId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception('A barátsági kérés nem található vagy már nem függőben lévő.');
      }

      final requestDocRef = querySnapshot.docs.first.reference;
      await requestDocRef.delete(); // Töröljük a kérést

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barátsági kérés visszavonva.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba a kérés visszavonásakor: $e')),
      );
    }
  }

  /// Barátság megszüntetése.
  Future<void> _unfriend(String otherUserId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        // Keresd meg és töröld a barátsági kérést, ha létezik (pending, accepted, rejected státuszban)
        final querySnapshot = await _firestore
            .collection('friendRequests')
            .where('senderId', whereIn: [_currentUserId, otherUserId])
            .where('receiverId', whereIn: [_currentUserId, otherUserId])
            .get();

        for (var doc in querySnapshot.docs) {
          transaction.delete(doc.reference);
        }

        // Töröld egymást a barátlistákból (mindkét felhasználó számára)
        final currentUserFriendsRef = _firestore.collection('friends').doc(_currentUserId);
        transaction.update(
          currentUserFriendsRef,
          {
            'friendIds': FieldValue.arrayRemove([otherUserId])
          },
        );

        final otherUserFriendsRef = _firestore.collection('friends').doc(otherUserId);
        transaction.update(
          otherUserFriendsRef,
          {
            'friendIds': FieldValue.arrayRemove([_currentUserId])
          },
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A barátság megszüntetve.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba a barátság megszüntetésekor: $e')),
      );
    }
  }

  /// Segédmetódus a közös játékok listájának megtalálásához.
  List<Game> _findCommonGames(List<Game> user1Games, List<Game> user2Games) {
    // Készítünk egy Set-et az első felhasználó játékneveiből a gyors kereséshez.
    final Set<String> user1GameNames = user1Games.map((game) => game.name).toSet();
    // Visszaadjuk a második felhasználó azon játékait, amelyek szerepelnek az első felhasználó játéknevei között.
    return user2Games.where((game) => user1GameNames.contains(game.name)).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Ha a jelenlegi felhasználó UID-je nem áll rendelkezésre,
    // hibaüzenetet vagy töltőképernyőt jelenítünk meg.
    if (_currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Nincs bejelentkezett felhasználó.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Felhasználók'),
        actions: [
          const NotificationBell(),
          // Kapcsoló a közös játékok szűréséhez
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Text(
                  'Közös játékok',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white),
                ),
                Switch(
                  value: _showCommonGamesOnly,
                  onChanged: (value) {
                    setState(() {
                      _showCommonGamesOnly = value;
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Keresés név, email vagy játék alapján...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('userProfiles').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Hiba: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nincsenek felhasználók.'));
                }

                // Szűrés a keresési lekérdezés alapján
                final allUserProfiles = snapshot.data!.docs.map((doc) {
                  return UserProfile.fromFirestore(doc.data() as Map<String, dynamic>);
                }).toList();

                // Saját profil kizárása — a keresési szűrést lentebb, a játékadatokkal együtt végezzük
                final filteredUserProfiles = allUserProfiles
                    .where((u) => u.uid != _currentUserId)
                    .toList();

                if (filteredUserProfiles.isEmpty) {
                  return const Center(child: Text('Nincsenek felhasználók.'));
                }

                return ListView.builder(
                  itemCount: filteredUserProfiles.length,
                  itemBuilder: (context, index) {
                    final userProfile = filteredUserProfiles[index];

                    // Nested StreamBuilder, hogy lekérjük a másik felhasználó játékait
                    return StreamBuilder<List<Game>>(
                      stream: _gameService.getGamesStreamForUser(userProfile.uid),
                      builder: (context, otherUserGamesSnapshot) {
                        if (otherUserGamesSnapshot.connectionState == ConnectionState.waiting) {
                          // Töltési állapotban csak egy üres dobozt adunk vissza, hogy ne blokkolja a listát.
                          return const SizedBox.shrink();
                        }
                        if (otherUserGamesSnapshot.hasError) {
                          // Hiba esetén semmit sem jelenítünk meg, vagy egy kis hibajelzést.
                          return const SizedBox.shrink();
                        }

                        final otherUserGames = otherUserGamesSnapshot.data ?? [];
                        final commonGames = _findCommonGames(_currentUserGames, otherUserGames);

                        final q = _searchQuery.toLowerCase();
                        final nameMatch = q.isEmpty ||
                            userProfile.displayName.toLowerCase().contains(q) ||
                            userProfile.email.toLowerCase().contains(q);
                        final gameMatch = q.isNotEmpty &&
                            otherUserGames.any((g) => g.name.toLowerCase().contains(q));

                        if (!nameMatch && !gameMatch) return const SizedBox.shrink();
                        if (_showCommonGamesOnly && commonGames.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Lekerekített sarkok
                          child: ListTile(
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: StatusDot.colorFor(userProfile.status),
                                  width: 3,
                                ),
                              ),
                              child: ProfileAvatar(
                                imageUrl: userProfile.profileImageUrl,
                                fallbackLetter: userProfile.displayName,
                                radius: 20,
                              ),
                            ),
                            title: Text(userProfile.displayName, style: Theme.of(context).textTheme.titleMedium),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userProfile.bio.isNotEmpty ? userProfile.bio : 'Nincs bemutatkozás',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (commonGames.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  // Közös játékok megjelenítése Chip-ekkel
                                  Wrap(
                                    spacing: 6.0, // Horizontális térköz a chipek között
                                    runSpacing: 4.0, // Vertikális térköz a sorok között
                                    children: commonGames.map((game) {
                                      return Chip(
                                        label: Text(game.name),
                                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                        labelStyle: TextStyle(
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                          fontSize: 12,
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                            onTap: () {
                              // Navigálás a UserViewPage-re (másik felhasználó profiljának megtekintése)
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserViewPage(
                                    userId: userProfile.uid,
                                    userEmail: userProfile.email,
                                  ),
                                ),
                              );
                            },
                            trailing: StreamBuilder<String>(
                              stream: _getFriendshipStatusStream(userProfile.uid),
                              builder: (context, statusSnapshot) {
                                if (statusSnapshot.connectionState == ConnectionState.waiting) {
                                  return const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  );
                                }
                                if (statusSnapshot.hasError) {
                                  return const Icon(Icons.error, color: Colors.red);
                                }

                                final friendshipStatus = statusSnapshot.data ?? 'none';

                                // Gombok a státusz alapján
                                if (friendshipStatus == 'none') {
                                  return IconButton(
                                    icon: const Icon(Icons.person_add),
                                    color: Colors.blueAccent,
                                    onPressed: () => _sendFriendRequest(userProfile.uid),
                                    tooltip: 'Barátsági kérés küldése',
                                  );
                                } else if (friendshipStatus == 'sent') {
                                  return IconButton(
                                    icon: const Icon(Icons.hourglass_empty),
                                    color: StatusDot.colorFor(userProfile.status),
                                    onPressed: () => _cancelFriendRequest(userProfile.uid),
                                    tooltip: 'Függőben lévő kérés visszavonása',
                                  );
                                } else if (friendshipStatus == 'received') {
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check),
                                        color: Colors.green,
                                        onPressed: () => _acceptFriendRequest(userProfile.uid),
                                        tooltip: 'Kérés elfogadása',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close),
                                        color: Colors.red,
                                        onPressed: () => _rejectFriendRequest(userProfile.uid),
                                        tooltip: 'Kérés elutasítása',
                                      ),
                                    ],
                                  );
                                } else if (friendshipStatus == 'friends') {
                                  return IconButton(
                                    icon: const Icon(Icons.people),
                                    color: Colors.deepPurple,
                                    onPressed: () => _unfriend(userProfile.uid),
                                    tooltip: 'Barátok (Kattints a megszüntetéshez)',
                                  );
                                }
                                return const SizedBox.shrink(); // Rejtett gomb egyéb státuszok esetén
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
