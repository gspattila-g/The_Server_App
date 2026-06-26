import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_profile.dart';
import '../../widgets/profile_avatar.dart';
import '../../models/game.dart'; // <<< Importáljuk a Game modellt
import '../../services/profile_service.dart';
import '../../services/chat_service.dart'; // ChatService a chat indításához
import '../../services/game_service.dart'; // <<< Importáljuk a GameService-t
import '../chat/chat_page.dart'; // ChatPage importálása

/// Egy oldal, amely egy másik felhasználó profilját jeleníti meg.
///
/// Tartalmazza a felhasználó nevét, bemutatkozását, kedvenc játékát és
/// egy gombot a barátsági állapot kezelésére vagy chat indítására.
/// Most már megjeleníti a felhasználó játékgyűjteményét is.
class UserViewPage extends StatefulWidget {
  final String userId; // A megtekintendő felhasználó UID-je
  final String userEmail; // A megtekintendő felhasználó email címe (pl. fallback címhez)

  const UserViewPage({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<UserViewPage> createState() => _UserViewPageState();
}

class _UserViewPageState extends State<UserViewPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProfileService _profileService = ProfileService();
  final ChatService _chatService = ChatService();
  final GameService _gameService = GameService(); // GameService példány

  // A jelenlegi bejelentkezett felhasználó UID-je
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Állapotváltozó a barátság státuszának tárolására
  // Lehetséges értékek: 'none', 'sent', 'received', 'friends', 'self'
  String _friendshipStatus = 'none';

  @override
  void initState() {
    super.initState();
    // Kezdeti barátsági státusz beállítása (ez csak egyszer fut le,
    // de a StreamBuilder fogja valós időben frissíteni)
    if (_currentUserId == widget.userId) {
      _friendshipStatus = 'self';
    }
  }

  // Segédmetódus a barátság státuszának streameléséhez
  Stream<String> _getFriendshipStatusStream() {
    if (_currentUserId == null || widget.userId == _currentUserId) {
      return Stream.value('self'); // Saját profil esetén
    }

    // Figyeljük a barátsági kéréseket, ahol az egyik fél mi vagyunk, a másik a megtekintett felhasználó
    return _firestore
        .collection('friendRequests')
        .where('senderId', whereIn: [_currentUserId, widget.userId])
        .where('receiverId', whereIn: [_currentUserId, widget.userId])
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        // Nincs aktív kérés vagy elfogadott barátság közöttük
        return 'none';
      } else {
        // Mivel unique id-t generálunk, elég az első dokumentumot vizsgálni
        final doc = snapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
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

  /// Barátsági kérés elküldése a megtekintett felhasználónak.
  Future<void> _sendFriendRequest() async {
    if (_currentUserId == null) return;

    try {
      // Ellenőrizzük, hogy nincs-e már függőben lévő kérés vagy barátság
      final existingRequests = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: _currentUserId)
          .where('receiverId', isEqualTo: widget.userId)
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
          .where('senderId', isEqualTo: widget.userId)
          .where('receiverId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();

      if (reversedRequests.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ez a felhasználó már küldött neked barátsági kérést. Kérlek, fogadd el a Közösség oldalon.')),
        );
        return;
      }

      // Barátsági kérés hozzáadása a Firestore-hoz
      await _firestore.collection('friendRequests').add({
        'senderId': _currentUserId,
        'receiverId': widget.userId,
        'status': 'pending', // 'pending', 'accepted', 'rejected'
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

  /// Barátsági kérés elfogadása a megtekintett felhasználótól.
  Future<void> _acceptFriendRequest() async {
    if (_currentUserId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        // Megkeressük a bejövő kérést
        final querySnapshot = await _firestore
            .collection('friendRequests')
            .where('senderId', isEqualTo: widget.userId)
            .where('receiverId', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'pending')
            .get();

        if (querySnapshot.docs.isEmpty) {
          throw Exception('A barátsági kérés nem található vagy már nem függőben lévő.');
        }

        final requestDocRef = querySnapshot.docs.first.reference;
        transaction.update(requestDocRef, {'status': 'accepted'});

        // Hozzáadjuk egymást a barátlistákhoz (mindkét felhasználó számára)
        final currentUserFriendsRef = _firestore.collection('friends').doc(_currentUserId);
        transaction.set(
          currentUserFriendsRef,
          {
            'friendIds': FieldValue.arrayUnion([widget.userId])
          },
          SetOptions(merge: true),
        );

        final senderFriendsRef = _firestore.collection('friends').doc(widget.userId);
        transaction.set(
          senderFriendsRef,
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
  Future<void> _rejectFriendRequest() async {
    if (_currentUserId == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: widget.userId)
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
  Future<void> _cancelFriendRequest() async {
    if (_currentUserId == null) return;

    try {
      final querySnapshot = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: _currentUserId)
          .where('receiverId', isEqualTo: widget.userId)
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
  Future<void> _unfriend() async {
    if (_currentUserId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        // Keresd meg és töröld a barátsági kérést, ha létezik (pending, accepted, rejected státuszban)
        final querySnapshot = await _firestore
            .collection('friendRequests')
            .where('senderId', whereIn: [_currentUserId, widget.userId])
            .where('receiverId', whereIn: [_currentUserId, widget.userId])
            .get();

        for (var doc in querySnapshot.docs) {
          transaction.delete(doc.reference);
        }

        // Töröld egymást a barátlistákból (mindkét felhasználó számára)
        final currentUserFriendsRef = _firestore.collection('friends').doc(_currentUserId);
        transaction.update(
          currentUserFriendsRef,
          {
            'friendIds': FieldValue.arrayRemove([widget.userId])
          },
        );

        final otherUserFriendsRef = _firestore.collection('friends').doc(widget.userId);
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

  // Segédmetódus a státuszszöveg lokalizálásához
  String _getLocalizedGameStatus(String status) {
    switch (status) {
      case 'wishlist':
        return 'Kívánságlista';
      case 'playing':
        return 'Játszom';
      case 'completed':
        return 'Befejeztem';
      case 'dropped':
        return 'Abbahagytam';
      default:
        return 'Ismeretlen';
    }
  }

  // Segédmetódus a státuszszöveg színének beállításához
  Color _getStatusColor(String status) {
    switch (status) {
      case 'wishlist':
        return Colors.orange;
      case 'playing':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'dropped':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Saját profil megtekintése esetén
    if (_currentUserId == widget.userId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profilom')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Ez a te profilod. A profilodat a "Több" -> "Profil" menüpont alatt szerkesztheted.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Felhasználó megtekintése'),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.getProfileStream(widget.userId),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profileSnapshot.hasError) {
            return Center(child: Text('Hiba: ${profileSnapshot.error}'));
          }
          if (!profileSnapshot.hasData || profileSnapshot.data == null) {
            return const Center(child: Text('Felhasználó nem található.'));
          }

          final userProfile = profileSnapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Profilkép és felhasználónév
              Column(
                children: [
                  ProfileAvatar(
                    imageUrl: userProfile.profileImageUrl,
                    fallbackLetter: userProfile.displayName,
                    radius: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userProfile.displayName,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  Text(
                    userProfile.email,
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userProfile.bio,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kedvenc játék: ${userProfile.favoriteGame}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                ],
              ),

              // Barátság státusz és gombok (StreamBuilderrel frissítve)
              StreamBuilder<String>(
                stream: _getFriendshipStatusStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Hiba a barátság státusz lekérésekor: ${snapshot.error}'));
                  }

                  _friendshipStatus = snapshot.data ?? 'none'; // Frissítjük a státuszt

                  return Column(
                    children: [
                      // Chat gomb (mindig látható, ha nem saját profil)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                receiverUserId: widget.userId,
                                receiverUserEmail: widget.userEmail,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.message),
                        label: const Text('Üzenet küldése'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                      ),
                      const SizedBox(height: 10),

                      // Barátság kezelő gombok a státusz alapján
                      if (_friendshipStatus == 'none')
                        ElevatedButton.icon(
                          onPressed: _sendFriendRequest,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Barátsági kérés küldése'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            minimumSize: const Size.fromHeight(40),
                          ),
                        )
                      else if (_friendshipStatus == 'sent')
                        ElevatedButton.icon(
                          onPressed: _cancelFriendRequest,
                          icon: const Icon(Icons.person_remove),
                          label: const Text('Barátsági kérés visszavonása'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            minimumSize: const Size.fromHeight(40),
                          ),
                        )
                      else if (_friendshipStatus == 'received')
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _acceptFriendRequest,
                                  icon: const Icon(Icons.check),
                                  label: const Text('Kérés elfogadása'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    minimumSize: const Size.fromHeight(40),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _rejectFriendRequest,
                                  icon: const Icon(Icons.close),
                                  label: const Text('Elutasítás'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    minimumSize: const Size.fromHeight(40),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (_friendshipStatus == 'friends')
                            ElevatedButton.icon(
                              onPressed: _unfriend,
                              icon: const Icon(Icons.people),
                              label: const Text('Barátság megszüntetése'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                minimumSize: const Size.fromHeight(40),
                              ),
                            ),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),

              // Játékgyűjtemény
              Text(
                'Játékgyűjteménye:',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              StreamBuilder<List<Game>>(
                stream: _gameService.getGamesStreamForUser(widget.userId),
                builder: (context, gameSnapshot) {
                  if (gameSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (gameSnapshot.hasError) {
                    return Center(child: Text('Hiba a játékok betöltésekor: ${gameSnapshot.error}'));
                  }
                  if (!gameSnapshot.hasData || gameSnapshot.data!.isEmpty) {
                    return const Center(child: Text('Nincsenek játékok a gyűjteményben.'));
                  }

                  final games = gameSnapshot.data!;

                  return ListView.builder(
                    shrinkWrap: true, // Fontos, hogy ne foglaljon végtelen helyet
                    physics: const NeverScrollableScrollPhysics(), // Ne legyen saját görgetése
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      final game = games[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.name,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(5),
                                      color: game.status == 'playing'
                                          ? Colors.green[100]
                                          : game.status == 'completed'
                                          ? Colors.blue[100]
                                          : game.status == 'wishlist'
                                          ? Colors.orange[100]
                                          : Colors.red[100],
                                    ),
                                    child: Text(
                                      _getLocalizedGameStatus(game.status),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: game.status == 'playing'
                                            ? Colors.green[800]
                                            : game.status == 'completed'
                                            ? Colors.blue[800]
                                            : game.status == 'wishlist'
                                            ? Colors.orange[800]
                                            : Colors.red[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text('Műfaj: ${game.genre}', style: const TextStyle(fontSize: 14)),
                              Text('Platform: ${game.platform}', style: const TextStyle(fontSize: 14)),
                              const SizedBox(height: 5),
                              Text(
                                'Hozzáadva: ${_formatTimestamp(game.addedAt)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // Időbélyeg formázása olvasható stringgé.
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'néhány másodperce';
    if (difference.inMinutes < 60) return '${difference.inMinutes} perce';
    if (difference.inHours < 24) return '${difference.inHours} órája';
    return '${date.year}.${date.month}.${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
