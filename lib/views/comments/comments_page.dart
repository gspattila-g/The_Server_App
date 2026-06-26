import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/profile_service.dart'; // A kommentelő displayName-ének lekéréséhez

/// Egy oldal, amely egy adott poszthoz tartozó kommenteket jeleníti meg és kezeli.
///
/// Lehetővé teszi a felhasználóknak, hogy kommenteket olvassanak és újakat adjanak hozzá.
class CommentsPage extends StatefulWidget {
  final String postId; // Annak a posztnak az ID-je, amelyhez a kommentek tartoznak
  final String postMessage; // A poszt üzenete (a fejlécben való megjelenítéshez)
  final String postSenderDisplayName; // A posztoló neve (a fejlécben való megjelenítéshez)

  const CommentsPage({
    super.key,
    required this.postId,
    required this.postMessage,
    required this.postSenderDisplayName,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  final ProfileService _profileService = ProfileService(); // Szükséges a felhasználó nevének lekéréséhez

  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid; // Jelenlegi felhasználó UID-je

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// Új komment hozzáadása a poszthoz.
  Future<void> _addComment() async {
    if (_commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A komment nem lehet üres!')),
      );
      return;
    }
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiba: Nincs bejelentkezett felhasználó a kommenteléshez.')),
      );
      return;
    }

    try {
      // Lekérjük a kommentelő felhasználó profilját a megjelenítendő névhez.
      final currentUserProfile = await _profileService.getProfile(_currentUserId!);
      final senderDisplayName = currentUserProfile?.displayName ?? 'Ismeretlen';

      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments') // Kommentek alkollekció
          .add({
        'senderId': _currentUserId,
        'senderDisplayName': senderDisplayName,
        'commentText': _commentController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      _commentController.clear(); // Komment elküldése után töröljük a beviteli mezőt
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hiba a komment hozzáadásakor: $e')),
      );
    }
  }

  /// Komment elemének felépítése.
  Widget _buildCommentItem(Map<String, dynamic> commentData) {
    final String senderDisplayName = commentData['senderDisplayName'] ?? 'Ismeretlen';
    final String commentText = commentData['commentText'] ?? '';
    final Timestamp? timestamp = commentData['timestamp'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  senderDisplayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(commentText, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  /// Időbélyeg formázása olvasható stringgé.
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'ismeretlen időpont';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'néhány másodperce';
    if (difference.inMinutes < 60) return '${difference.inMinutes} perce';
    if (difference.inHours < 24) return '${difference.inHours} órája';
    return '${date.year}.${date.month}.${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      // Itt a Scaffold nem lehet 'const', mert a benne lévő AppBar sem 'const'.
      // Ezért eltávolítottuk a 'const' kulcsszót a 'Scaffold' elől.
      return Scaffold( // <<< EZT MÓDOSÍTOTTAM! ELTÁVOLÍTOTTAM A 'const' KULCSSZÓT A SCAFFOLD ELŐL!
        appBar: AppBar(title: const Text('Kommentek')), // Az AppBar címe lehet 'const Text'
        body: const Center(child: Text('Hiba: Nincs bejelentkezett felhasználó.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kommentek'),
        bottom: PreferredSize( // A poszt üzenetének megjelenítése az AppBar alatt
          preferredSize: const Size.fromHeight(kToolbarHeight + 20), // Növelt magasság
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.postSenderDisplayName} posztja:',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Text(
                  widget.postMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Kommentek listája
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Lekérdezzük az adott poszt kommentjeit, időbélyeg szerint rendezve
              stream: _firestore
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true) // Legújabb kommentek felül
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Hiba a kommentek betöltésekor: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Még nincs komment. Légy te az első!'));
                }

                final comments = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final commentData = comments[index].data() as Map<String, dynamic>;
                    return _buildCommentItem(commentData);
                  },
                );
              },
            ),
          ),
          // Komment beviteli mező és küldés gomb
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Írj kommentet...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                    obscureText: false,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
