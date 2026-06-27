import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_profile.dart';
import '../../models/notification.dart';
import '../../widgets/profile_avatar.dart';

import '../home/new_post_page.dart';
import '../../services/profile_service.dart';
import '../../services/notification_service.dart';
import '../comments/comments_page.dart';

/// A főoldal, amely megjeleníti a felhasználók posztjait.
///
/// Lehetővé teszi új posztok létrehozását és a meglévő posztok lájkolását.
class HomePage extends StatefulWidget {
  final String userEmail;

  const HomePage({super.key, required this.userEmail});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProfileService _profileService = ProfileService();
  final NotificationService _notificationService = NotificationService();
  final Map<String, UserProfile> _profileCache = {};
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _addNewPost(BuildContext context, String text, String? imageUrl) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiba: Nincs bejelentkezett felhasználó. Posztolás sikertelen.')),
      );
      return;
    }

    try {
      final userProfile = await _profileService.getProfile(_currentUserId!);
      final userDisplayName = userProfile?.displayName ?? 'Ismeretlen Felhasználó';

      await _firestore.collection('posts').add({
        'message': text,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': _currentUserId,
        'senderDisplayName': userDisplayName,
        'likes': [],
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Poszt sikeresen közzétéve!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba a poszt közzétételekor: $e')),
      );
    }
  }

  /// Kezeli a lájkolást/nem lájkolást egy poszton.
  ///
  /// Frissíti a 'likes' tömböt a Firestore-ban.
  Future<void> _toggleLike(String postId, List<dynamic> currentLikes, String postOwnerId) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiba: Be kell jelentkezni a lájkoláshoz.')),
      );
      return;
    }

    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final alreadyLiked = currentLikes.contains(_currentUserId);

      if (alreadyLiked) {
        await postRef.update({'likes': FieldValue.arrayRemove([_currentUserId])});
      } else {
        await postRef.update({'likes': FieldValue.arrayUnion([_currentUserId])});

        // Értesítés küldése ha nem saját posztot lájkol
        if (postOwnerId != _currentUserId) {
          final senderProfile = await _profileService.getProfile(_currentUserId!);
          final senderName = senderProfile?.displayName ?? 'Valaki';
          await _notificationService.addNotification(AppNotification(
            senderId: _currentUserId!,
            receiverId: postOwnerId,
            type: 'like',
            message: '$senderName lájkolta a posztodat.',
            eventId: postId,
            timestamp: Timestamp.now(),
          ));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba a lájkolás frissítésekor: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ha a jelenlegi felhasználó UID-je nem áll rendelkezésre,
    // hibaüzenetet vagy töltőképernyőt jelenítünk meg.
    if (_currentUserId == null) {
      return const Center(
        child: Text('Hiba: Nincs bejelentkezett felhasználó azonosító.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Főoldal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            tooltip: 'Új poszt',
            onPressed: () async {
              final result = await Navigator.push<Map<String, dynamic?>>(
                context,
                MaterialPageRoute(builder: (context) => const NewPostPage()),
              );
              if (result != null) {
                final text = (result['text'] as String?) ?? '';
                final imageUrl = result['imageUrl'] as String?;
                _addNewPost(context, text, imageUrl);
              }
            },
          ),
        ],
      ),
      // A StreamBuilder valós időben figyeli a 'posts' kollekciót.
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('posts').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          // Ha még várunk az adatokra.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Hiba esetén.
          if (snapshot.hasError) {
            return Center(child: Text('Hiba történt a posztok betöltésekor: ${snapshot.error}'));
          }

          // Ha nincs adat (üres kollekció).
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Még nincsenek posztok. Légy te az első!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Posztok listájának megjelenítése.
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final post = snapshot.data!.docs[index];
              return _buildPostCard(post);
            },
          );
        },
      ),
    );
  }

  /// Építi fel az egyes posztok kártya nézetét.
  Widget _buildPostCard(DocumentSnapshot post) {
    final Map<String, dynamic> data = post.data() as Map<String, dynamic>;
    final String postId = post.id;
    final String message = data['message'] ?? '';
    final String? imageUrl = data['imageUrl'] as String?;
    final String senderId = data['senderId'] ?? '';
    final Timestamp timestamp = data['timestamp'] ?? Timestamp.now();
    final List<dynamic> likes = data['likes'] ?? [];
    final bool isLikedByCurrentUser = likes.contains(_currentUserId);

    // Lekérjük a posztoló megjelenítendő nevét.
    return FutureBuilder<UserProfile?>(
      future: _profileCache.containsKey(senderId)
          ? Future.value(_profileCache[senderId])
          : _profileService.getProfile(senderId).then((profile) {
        if (profile != null) _profileCache[senderId] = profile;
        return profile;
      }),
      builder: (context, profileSnapshot) {
        final String userDisplayName = profileSnapshot.data?.displayName ?? data['senderDisplayName'] ?? 'Ismeretlen Felhasználó';
        final String? profileImageUrl = profileSnapshot.data?.profileImageUrl;

        // Kommentek számának lekérdezése
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('posts').doc(postId).collection('comments').snapshots(),
          builder: (context, commentSnapshot) {
            if (commentSnapshot.connectionState == ConnectionState.waiting) {
              // Kommentek betöltése folyamatban, megjelenítjük a kártyát alap adatokkal
            }
            final int commentCount = commentSnapshot.data?.docs.length ?? 0;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Felhasználó adatai és időbélyeg
                    Row(
                      children: [
                        ProfileAvatar(
                          imageUrl: profileImageUrl,
                          fallbackLetter: userDisplayName,
                          radius: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userDisplayName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              Text(
                                _formatTimestamp(timestamp),
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (message.isNotEmpty)
                      Text(message, style: const TextStyle(fontSize: 16)),
                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                      if (message.isNotEmpty) const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) => progress == null
                              ? child
                              : const SizedBox(
                                  height: 180,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                          errorBuilder: (_, __, ___) => const SizedBox(
                            height: 60,
                            child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Lájk és komment szekció
                    Row(
                      children: [
                        // Lájk gomb
                        IconButton(
                          icon: Icon(
                            isLikedByCurrentUser ? Icons.favorite : Icons.favorite_border,
                            color: isLikedByCurrentUser ? Colors.red : Colors.grey,
                          ),
                          onPressed: () => _toggleLike(postId, likes, senderId),
                        ),
                        Text('${likes.length} lájk', style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 20),
                        // Komment gomb
                        IconButton(
                          icon: const Icon(Icons.comment),
                          onPressed: () {
                            // Navigálás a CommentsPage-re
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CommentsPage(
                                  postId: postId,
                                  postMessage: message,
                                  postSenderId: senderId,
                                  postSenderDisplayName: userDisplayName,
                                ),
                              ),
                            );
                          },
                        ),
                        Text('$commentCount komment', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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
