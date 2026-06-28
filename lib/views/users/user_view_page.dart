import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_profile.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/status_dot.dart';
import '../../models/game.dart';
import '../../services/profile_service.dart';
import '../../services/chat_service.dart';
import '../../services/game_service.dart';
import '../chat/chat_page.dart';

class UserViewPage extends StatefulWidget {
  final String userId;
  final String userEmail;

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
  final GameService _gameService = GameService();

  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Stream<String> _getFriendshipStatusStream() {
    if (_currentUserId == null || widget.userId == _currentUserId) {
      return Stream.value('self');
    }
    return _firestore
        .collection('friendRequests')
        .where('senderId', whereIn: [_currentUserId, widget.userId])
        .where('receiverId', whereIn: [_currentUserId, widget.userId])
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return 'none';
      final doc = snapshot.docs.first;
      final data = doc.data();
      final status = data['status'] as String;
      final senderId = data['senderId'] as String;
      if (status == 'accepted') return 'friends';
      if (status == 'pending') {
        return senderId == _currentUserId ? 'sent' : 'received';
      }
      return 'none';
    });
  }

  Future<void> _sendFriendRequest() async {
    if (_currentUserId == null) return;
    try {
      final existing = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: _currentUserId)
          .where('receiverId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (existing.docs.isNotEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Már küldtél barátsági kérést.')));
        return;
      }
      final reversed = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: widget.userId)
          .where('receiverId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (reversed.docs.isNotEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ez a felhasználó már küldött neked kérést.')));
        return;
      }
      await _firestore.collection('friendRequests').add({
        'senderId': _currentUserId,
        'receiverId': widget.userId,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barátsági kérés elküldve!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba: $e')));
    }
  }

  Future<void> _acceptFriendRequest() async {
    if (_currentUserId == null) return;
    try {
      await _firestore.runTransaction((transaction) async {
        final query = await _firestore
            .collection('friendRequests')
            .where('senderId', isEqualTo: widget.userId)
            .where('receiverId', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'pending')
            .get();
        if (query.docs.isEmpty) throw Exception('Kérés nem található.');
        transaction.update(query.docs.first.reference, {'status': 'accepted'});
        transaction.set(
          _firestore.collection('friends').doc(_currentUserId),
          {'friendIds': FieldValue.arrayUnion([widget.userId])},
          SetOptions(merge: true),
        );
        transaction.set(
          _firestore.collection('friends').doc(widget.userId),
          {'friendIds': FieldValue.arrayUnion([_currentUserId])},
          SetOptions(merge: true),
        );
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barátsági kérés elfogadva!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba: $e')));
    }
  }

  Future<void> _rejectFriendRequest() async {
    if (_currentUserId == null) return;
    try {
      final query = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: widget.userId)
          .where('receiverId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (query.docs.isEmpty) throw Exception('Kérés nem található.');
      await query.docs.first.reference.update({'status': 'rejected'});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barátsági kérés elutasítva.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba: $e')));
    }
  }

  Future<void> _cancelFriendRequest() async {
    if (_currentUserId == null) return;
    try {
      final query = await _firestore
          .collection('friendRequests')
          .where('senderId', isEqualTo: _currentUserId)
          .where('receiverId', isEqualTo: widget.userId)
          .where('status', isEqualTo: 'pending')
          .get();
      if (query.docs.isEmpty) throw Exception('Kérés nem található.');
      await query.docs.first.reference.delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barátsági kérés visszavonva.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba: $e')));
    }
  }

  Future<void> _unfriend() async {
    if (_currentUserId == null) return;
    try {
      await _firestore.runTransaction((transaction) async {
        final query = await _firestore
            .collection('friendRequests')
            .where('senderId', whereIn: [_currentUserId, widget.userId])
            .where('receiverId', whereIn: [_currentUserId, widget.userId])
            .get();
        for (final doc in query.docs) {
          transaction.delete(doc.reference);
        }
        transaction.update(
          _firestore.collection('friends').doc(_currentUserId),
          {'friendIds': FieldValue.arrayRemove([widget.userId])},
        );
        transaction.update(
          _firestore.collection('friends').doc(widget.userId),
          {'friendIds': FieldValue.arrayRemove([_currentUserId])},
        );
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Barátság megszüntetve.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba: $e')));
    }
  }

  Widget _buildStatColumn(int count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$count', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }

  String _getLocalizedGameStatus(String status) {
    switch (status) {
      case 'wishlist': return 'Kívánságlista';
      case 'playing': return 'Játszom';
      case 'completed': return 'Befejeztem';
      case 'dropped': return 'Abbahagytam';
      default: return 'Ismeretlen';
    }
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(title: const Text('Felhasználó megtekintése')),
      body: StreamBuilder<UserProfile?>(
        stream: _profileService.getProfileStream(widget.userId),
        builder: (context, profileSnapshot) {
          if (profileSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!profileSnapshot.hasData || profileSnapshot.data == null) {
            return const Center(child: Text('Felhasználó nem található.'));
          }

          final userProfile = profileSnapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Column(
                children: [
                  ProfileAvatar(
                    imageUrl: userProfile.profileImageUrl,
                    fallbackLetter: userProfile.displayName,
                    radius: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(userProfile.displayName, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StatusDot(status: userProfile.status, size: 12),
                      const SizedBox(width: 6),
                      Text(StatusDot.labelFor(userProfile.status),
                          style: TextStyle(color: StatusDot.colorFor(userProfile.status), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('posts')
                            .where('senderId', isEqualTo: widget.userId)
                            .snapshots(),
                        builder: (context, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          return _buildStatColumn(count, 'Poszt');
                        },
                      ),
                      Container(
                        width: 1, height: 40,
                        color: Colors.grey.withOpacity(0.4),
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      StreamBuilder<DocumentSnapshot>(
                        stream: _firestore
                            .collection('friends')
                            .doc(widget.userId)
                            .snapshots(),
                        builder: (context, snap) {
                          final data = snap.data?.data() as Map<String, dynamic>?;
                          final count = (data?['friendIds'] as List?)?.length ?? 0;
                          return _buildStatColumn(count, 'Barát');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(userProfile.email, style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Colors.grey)),
                  const SizedBox(height: 16),
                  Text(userProfile.bio, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text('Kedvenc játék: ${userProfile.favoriteGame}', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                ],
              ),

              StreamBuilder<String>(
                stream: _getFriendshipStatusStream(),
                builder: (context, snapshot) {
                  final status = snapshot.data ?? 'none';
                  return Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatPage(
                              receiverUserId: widget.userId,
                              receiverUserEmail: widget.userEmail,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.message),
                        label: const Text('Üzenet küldése'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                      ),
                      const SizedBox(height: 10),
                      if (status == 'none')
                        ElevatedButton.icon(
                          onPressed: _sendFriendRequest,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Barátsági kérés küldése'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            minimumSize: const Size.fromHeight(40),
                          ),
                        )
                      else if (status == 'sent')
                        ElevatedButton.icon(
                          onPressed: _cancelFriendRequest,
                          icon: const Icon(Icons.person_remove),
                          label: const Text('Barátsági kérés visszavonása'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            minimumSize: const Size.fromHeight(40),
                          ),
                        )
                      else if (status == 'received')
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
                      else if (status == 'friends')
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

              if (_currentUserId != null) ...[
                StreamBuilder<List<Game>>(
                  stream: _gameService.getGamesStreamForUser(_currentUserId!),
                  builder: (context, mySnap) {
                    return StreamBuilder<List<Game>>(
                      stream: _gameService.getGamesStreamForUser(widget.userId),
                      builder: (context, theirSnap) {
                        final myNames = mySnap.data
                                ?.map((g) => g.name.trim().toLowerCase())
                                .toSet() ??
                            {};
                        final common = theirSnap.data
                                ?.where((g) => myNames.contains(g.name.trim().toLowerCase()))
                                .toList() ??
                            [];
                        if (common.isEmpty) return const SizedBox.shrink();
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.people, size: 20),
                                const SizedBox(width: 6),
                                Text('Közös játékok (${common.length})',
                                    style: Theme.of(context).textTheme.titleLarge),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: common.map((game) {
                                final color = game.status == 'playing'
                                    ? Colors.green
                                    : game.status == 'completed'
                                        ? Colors.blue
                                        : game.status == 'wishlist'
                                            ? Colors.orange
                                            : Colors.red;
                                return Chip(
                                  avatar: Icon(Icons.videogame_asset, size: 16, color: color),
                                  label: Text(game.name, style: const TextStyle(fontSize: 13)),
                                  backgroundColor: color.withOpacity(0.1),
                                  side: BorderSide(color: color.withOpacity(0.4)),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],

              Text('Játékgyűjteménye:', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              StreamBuilder<List<Game>>(
                stream: _gameService.getGamesStreamForUser(widget.userId),
                builder: (context, gameSnapshot) {
                  if (gameSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!gameSnapshot.hasData || gameSnapshot.data!.isEmpty) {
                    return const Center(child: Text('Nincsenek játékok a gyűjteményben.'));
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: gameSnapshot.data!.length,
                    itemBuilder: (context, index) {
                      final game = gameSnapshot.data![index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(game.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: game.status == 'playing' ? Colors.green[100]
                                      : game.status == 'completed' ? Colors.blue[100]
                                      : game.status == 'wishlist' ? Colors.orange[100]
                                      : Colors.red[100],
                                ),
                                child: Text(
                                  _getLocalizedGameStatus(game.status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: game.status == 'playing' ? Colors.green[800]
                                        : game.status == 'completed' ? Colors.blue[800]
                                        : game.status == 'wishlist' ? Colors.orange[800]
                                        : Colors.red[800],
                                  ),
                                ),
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
