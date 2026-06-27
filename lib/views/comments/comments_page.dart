import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/notification.dart';
import '../../services/notification_service.dart';
import '../../services/profile_service.dart';

/// Egy oldal, amely egy adott poszthoz tartozó kommenteket jeleníti meg és kezeli.
///
/// Lehetővé teszi a felhasználóknak, hogy kommenteket olvassanak és újakat adjanak hozzá.
class CommentsPage extends StatefulWidget {
  final String postId;
  final String postMessage;
  final String postSenderId;
  final String postSenderDisplayName;

  const CommentsPage({
    super.key,
    required this.postId,
    required this.postMessage,
    required this.postSenderId,
    required this.postSenderDisplayName,
  });

  @override
  State<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends State<CommentsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  final ProfileService _profileService = ProfileService();
  final NotificationService _notificationService = NotificationService();
  final ImagePicker _picker = ImagePicker();

  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  File? _selectedImage;
  bool _isSending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1080,
      );
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nem sikerült a kép kiválasztása.')),
        );
      }
    }
  }

  Future<String?> _uploadImage(File image) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$uid.jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('comment_images')
        .child(fileName);
    await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Írj valamit, vagy válassz képet!')),
      );
      return;
    }
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hiba: Nincs bejelentkezett felhasználó.')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final currentUserProfile = await _profileService.getProfile(_currentUserId!);
      final senderDisplayName = currentUserProfile?.displayName ?? 'Ismeretlen';

      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
      }

      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
        'senderId': _currentUserId,
        'senderDisplayName': senderDisplayName,
        'commentText': text,
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
      setState(() => _selectedImage = null);

      // Értesítés küldése ha nem saját posztjára kommentel
      if (widget.postSenderId != _currentUserId) {
        await _notificationService.addNotification(AppNotification(
          senderId: _currentUserId!,
          receiverId: widget.postSenderId,
          type: 'comment',
          message: '$senderDisplayName kommentelt a posztodra.',
          eventId: widget.postId,
          timestamp: Timestamp.now(),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a komment elküldésekor: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildCommentItem(Map<String, dynamic> commentData) {
    final String senderDisplayName = commentData['senderDisplayName'] ?? 'Ismeretlen';
    final String commentText = commentData['commentText'] ?? '';
    final String? imageUrl = commentData['imageUrl'] as String?;
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
            if (commentText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(commentText, style: const TextStyle(fontSize: 14)),
            ],
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          height: 120,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                  errorBuilder: (_, __, ___) => const SizedBox(
                    height: 60,
                    child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                  ),
                ),
              ),
            ],
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
          // Kiválasztott kép előnézete
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Komment beviteli mező és gombok
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: _isSending ? null : _pickImage,
                  icon: const Icon(Icons.image),
                  color: Theme.of(context).primaryColor,
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    enabled: !_isSending,
                    decoration: InputDecoration(
                      hintText: 'Írj kommentet...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
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
