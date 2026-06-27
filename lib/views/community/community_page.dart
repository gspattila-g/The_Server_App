import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_profile.dart';
import '../../widgets/profile_avatar.dart';
import '../chat/chat_page.dart'; // ChatPage importálása
import '../users/user_view_page.dart'; // UserViewPage importálása

/// Egy oldal, amely kezeli a barátsági kéréseket és megjeleníti a barátlistát.
///
/// Itt láthatja a felhasználó a bejövő kéréseket, elfogadhatja vagy elutasíthatja
/// azokat, és megtekintheti az aktuális barátait, valamint kereshet köztük.
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Szövegvezérlő a barátok keresőmezőjéhez.
  final TextEditingController _searchController = TextEditingController();
  // A barátok keresési lekérdezése.
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Figyeljük a barátok keresőmezőjének változásait.
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Kezeli a barátok keresőmezőjének szövegének változásait.
  /// Frissíti a _searchQuery állapotot.
  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase(); // Kisbetűssé alakítjuk a kereséshez
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(
        child: Text('Hiba: Nincs bejelentkezett felhasználó azonosító.'),
      );
    }

    return DefaultTabController(
      length: 2, // Két fül: Kérések és Barátok
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Barátok'),
          bottom: TabBar(
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withOpacity(0.7),
            indicatorColor: Theme.of(context).colorScheme.secondary,
            tabs: const [
              Tab(text: 'Barátok', icon: Icon(Icons.people_alt)),
              Tab(text: 'Kérések', icon: Icon(Icons.mail)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFriendsTab(),
            _buildRequestsTab(),
          ],
        ),
      ),
    );
  }

  /// Építi fel a 'Kérések' fül tartalmát.
  Widget _buildRequestsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('friendRequests')
          .where('receiverId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Hiba a kérések betöltésekor: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Nincsenek bejövő barátsági kérések.'));
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestData = requests[index].data() as Map<String, dynamic>;
            final senderId = requestData['senderId'] as String;
            final requestId = requests[index].id;

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('userProfiles').doc(senderId).get(),
              builder: (context, userProfileSnapshot) {
                if (userProfileSnapshot.connectionState == ConnectionState.waiting) {
                  return const ListTile(
                    title: Text('Felhasználó betöltése...'),
                    leading: CircularProgressIndicator(),
                  );
                }
                if (userProfileSnapshot.hasError) {
                  return ListTile(
                    title: Text('Hiba a felhasználó betöltésekor: ${userProfileSnapshot.error}'),
                  );
                }
                if (!userProfileSnapshot.hasData || !userProfileSnapshot.data!.exists) {
                  return const ListTile(
                    title: Text('Ismeretlen felhasználó'),
                  );
                }

                final senderProfile = UserProfile.fromFirestore(userProfileSnapshot.data!.data() as Map<String, dynamic>);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: senderProfile.profileImageUrl != null && senderProfile.profileImageUrl!.isNotEmpty
                          ? NetworkImage(senderProfile.profileImageUrl!)
                          : null,
                      child: (senderProfile.profileImageUrl == null || senderProfile.profileImageUrl!.isEmpty)
                          ? Text(senderProfile.displayName.isNotEmpty ? senderProfile.displayName[0].toUpperCase() : '?')
                          : null,
                    ),
                    title: Text('${senderProfile.displayName} barátsági kérést küldött'),
                    subtitle: Text(senderProfile.bio.isNotEmpty ? senderProfile.bio : 'Nincs bemutatkozás'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () => _acceptFriendRequest(requestId, senderId),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _rejectFriendRequest(requestId),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserViewPage(
                            userId: senderProfile.uid,
                            userEmail: senderProfile.email,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Építi fel a 'Barátok' fül tartalmát.
  /// Itt jelennek meg a felhasználó barátai, szűrhetően.
  Widget _buildFriendsTab() {
    return Column( // Column, hogy lehessen keresősáv és lista is
      children: [
        Padding( // KERESŐSÁV ÁTHELYEZVE IDE
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Barát keresése...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25.0),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _onSearchChanged(); // Keresési lekérdezés törlése
                },
              )
                  : null,
            ),
          ),
        ),
        Expanded( // Expanded, hogy a lista kitöltse a maradék helyet
          child: StreamBuilder<DocumentSnapshot>(
            stream: _firestore.collection('friends').doc(_currentUserId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Hiba a barátok betöltésekor: ${snapshot.error}'));
              }

              final Map<String, dynamic>? data = snapshot.data!.data() as Map<String, dynamic>?;

              if (!snapshot.hasData || !snapshot.data!.exists || data == null || !data.containsKey('friendIds')) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Még nincsenek barátaid. Küldj barátsági kéréseket a "Felhasználók" oldalon!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              final List<String> friendUids = List<String>.from(data['friendIds'] ?? []);

              if (friendUids.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Még nincsenek barátaid. Küldj barátsági kéréseket a "Felhasználók" oldalon!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              // FutureBuilder a barátok profiladatainak lekéréséhez
              return FutureBuilder<List<UserProfile>>(
                future: _getFriendsProfiles(friendUids),
                builder: (context, friendsProfileSnapshot) {
                  if (friendsProfileSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (friendsProfileSnapshot.hasError) {
                    return Center(child: Text('Hiba a barátok profiljának betöltésekor: ${friendsProfileSnapshot.error}'));
                  }
                  if (!friendsProfileSnapshot.hasData || friendsProfileSnapshot.data!.isEmpty) {
                    return const Center(child: Text('Hiba: Nem sikerült betölteni a barátok profiljait.'));
                  }

                  // Szűrjük a barátokat a keresési lekérdezés alapján
                  final List<UserProfile> allFriends = friendsProfileSnapshot.data!;
                  final List<UserProfile> filteredFriends = allFriends.where((friend) {
                    if (_searchQuery.isEmpty) {
                      return true; // Ha üres a kereső, minden barátot megmutatunk
                    } else {
                      // Ellenőrizzük, hogy a displayName tartalmazza-e a keresési lekérdezést
                      return friend.displayName.toLowerCase().contains(_searchQuery);
                    }
                  }).toList();

                  if (filteredFriends.isEmpty) {
                    return Center(child: Text(
                      _searchQuery.isEmpty
                          ? 'Még nincsenek barátaid.'
                          : 'Nincs találat a "${_searchController.text}" keresésre a barátok között.',
                    ));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: filteredFriends.length,
                    itemBuilder: (context, index) {
                      final friendProfile = filteredFriends[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2,
                        child: ListTile(
                          leading: CircleAvatar(
                              backgroundImage: friendProfile.profileImageUrl != null && friendProfile.profileImageUrl!.isNotEmpty
                                  ? NetworkImage(friendProfile.profileImageUrl!)
                                  : null,
                            child: (friendProfile.profileImageUrl == null || friendProfile.profileImageUrl!.isEmpty)
                                ? Text(
                              friendProfile.displayName.isNotEmpty
                                  ? friendProfile.displayName[0].toUpperCase()
                                  : '?',
                            )
                                : null,
                          ),
                          title: Text(friendProfile.displayName),
                          subtitle: Text(friendProfile.bio.isNotEmpty ? friendProfile.bio : 'Nincs bemutatkozás'),
                          trailing: IconButton(
                            icon: const Icon(Icons.chat),
                            color: Theme.of(context).primaryColor,
                            onPressed: () {
                              // Itt kellene navigálni a ChatPage-re.
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatPage(
                                    receiverUserId: friendProfile.uid,
                                    receiverUserEmail: friendProfile.email,
                                  ),
                                ),
                              );
                            },
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserViewPage(
                                  userId: friendProfile.uid,
                                  userEmail: friendProfile.email,
                                ),
                              ),
                            );
                          },
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
    );
  }

  /// Lekérdezi több felhasználó profilját a Firestore-ból a megadott UID-k alapján.
  Future<List<UserProfile>> _getFriendsProfiles(List<String> uids) async {
    if (uids.isEmpty) {
      return [];
    }
    final QuerySnapshot querySnapshot = await _firestore
        .collection('userProfiles')
        .where(FieldPath.documentId, whereIn: uids)
        .get();

    return querySnapshot.docs
        .map((doc) => UserProfile.fromFirestore(doc.data() as Map<String, dynamic>))
        .toList();
  }


  /// Elfogad egy bejövő barátsági kérést.
  Future<void> _acceptFriendRequest(String requestId, String senderId) async {
    if (_currentUserId == null) return;

    try {
      await _firestore.runTransaction((transaction) async {
        final requestDocRef = _firestore.collection('friendRequests').doc(requestId);
        transaction.update(requestDocRef, {'status': 'accepted'});

        final currentUserFriendsRef = _firestore.collection('friends').doc(_currentUserId);
        transaction.set(
          currentUserFriendsRef,
          {
            'friendIds': FieldValue.arrayUnion([senderId])
          },
          SetOptions(merge: true),
        );

        final senderFriendsRef = _firestore.collection('friends').doc(senderId);
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

  /// Elutasít egy bejövő barátsági kérést.
  Future<void> _rejectFriendRequest(String requestId) async {
    try {
      await _firestore.collection('friendRequests').doc(requestId).update({'status': 'rejected'});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Barátsági kérés elutasítva.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba a kérés elutasításakor: $e')),
      );
    }
  }
}
