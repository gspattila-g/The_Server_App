import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/notification.dart';
import '../../models/user_profile.dart';
import '../../services/notification_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/fullscreen_image_page.dart';
import '../users/user_view_page.dart';

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

  Future<void> _toggleLike(String postId, List<dynamic> currentLikes, String postOwnerId) async {
    if (_currentUserId == null) return;
    try {
      final postRef = _firestore.collection('posts').doc(postId);
      final alreadyLiked = currentLikes.contains(_currentUserId);
      if (alreadyLiked) {
        await postRef.update({'likes': FieldValue.arrayRemove([_currentUserId])});
      } else {
        await postRef.update({'likes': FieldValue.arrayUnion([_currentUserId])});
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba: $e')));
      }
    }
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
    final ref = FirebaseStorage.instance.ref().child('comment_images').child(fileName);
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

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Komment törlése'),
        content: const Text('Biztosan törlöd ezt a kommentet?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Mégse')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .doc(commentId)
          .delete();
    }
  }

  Future<void> _editComment(String commentId, String currentText, String? currentImageUrl) async {
    final controller = TextEditingController(text: currentText);
    File? newImage;
    bool removeExisting = false;
    bool isUploading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final bool showExisting = currentImageUrl != null && !removeExisting && newImage == null;
          final bool hasImage = showExisting || newImage != null;

          Future<void> pickImage() async {
            await showModalBottomSheet(
              context: ctx,
              builder: (_) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.photo_library),
                      title: const Text('Galéria'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1080);
                        if (picked != null) setDialogState(() { newImage = File(picked.path); removeExisting = false; });
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.camera_alt),
                      title: const Text('Kamera'),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1080);
                        if (picked != null) setDialogState(() { newImage = File(picked.path); removeExisting = false; });
                      },
                    ),
                  ],
                ),
              ),
            );
          }

          return AlertDialog(
            title: const Text('Komment szerkesztése'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Komment szövege...',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (newImage != null) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(newImage!, height: 150, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => setDialogState(() => newImage = null),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ] else if (showExisting) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(currentImageUrl!, height: 150, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => setDialogState(() => removeExisting = true),
                            child: Container(
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    onPressed: isUploading ? null : pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(hasImage ? 'Kép cseréje' : 'Kép hozzáadása'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: isUploading ? null : () => Navigator.pop(ctx), child: const Text('Mégse')),
              if (isUploading)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    final newText = controller.text.trim();
                    setDialogState(() => isUploading = true);
                    try {
                      String? finalImageUrl;
                      if (newImage != null) {
                        finalImageUrl = await _uploadImage(newImage!);
                      } else if (removeExisting) {
                        finalImageUrl = null;
                      } else {
                        finalImageUrl = currentImageUrl;
                      }
                      await _firestore
                          .collection('posts')
                          .doc(widget.postId)
                          .collection('comments')
                          .doc(commentId)
                          .update({'commentText': newText, 'imageUrl': finalImageUrl});
                      if (ctx.mounted) Navigator.pop(ctx);
                    } catch (e) {
                      setDialogState(() => isUploading = false);
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Hiba: $e')));
                      }
                    }
                  },
                  child: const Text('Mentés'),
                ),
            ],
          );
        },
      ),
    );
    controller.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inSeconds < 60) return 'néhány másodperce';
    if (difference.inMinutes < 60) return '${difference.inMinutes} perce';
    if (difference.inHours < 24) return '${difference.inHours} órája';
    return '${date.year}.${date.month}.${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildPostCard(Map<String, dynamic> data) {
    final likes = data['likes'] as List<dynamic>? ?? [];
    final isLiked = likes.contains(_currentUserId);
    final imageUrl = data['imageUrl'] as String?;
    final message = data['message'] as String? ?? widget.postMessage;
    final senderId = data['senderId'] as String? ?? widget.postSenderId;
    final senderDisplayName = data['senderDisplayName'] as String? ?? widget.postSenderDisplayName;
    final timestamp = data['timestamp'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<UserProfile?>(
              future: _profileService.getProfile(senderId),
              builder: (context, profileSnap) {
                final displayName = profileSnap.data?.displayName ?? senderDisplayName;
                final profileImageUrl = profileSnap.data?.profileImageUrl;
                final email = profileSnap.data?.email ?? '';
                return GestureDetector(
                  onTap: senderId != _currentUserId
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserViewPage(userId: senderId, userEmail: email),
                            ),
                          )
                      : null,
                  child: Row(
                    children: [
                      ProfileAvatar(
                        imageUrl: profileImageUrl,
                        fallbackLetter: displayName,
                        radius: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (timestamp != null)
                              Text(_formatTimestamp(timestamp), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(message, style: const TextStyle(fontSize: 16)),
            ],
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenImagePage(imageUrl: imageUrl))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 60,
                      child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey,
                  ),
                  onPressed: () => _toggleLike(widget.postId, likes, senderId),
                ),
                Text('${likes.length} lájk', style: const TextStyle(fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> commentData, String commentId) {
    final String senderDisplayName = commentData['senderDisplayName'] ?? 'Ismeretlen';
    final String senderId = commentData['senderId'] as String? ?? '';
    final String commentText = commentData['commentText'] ?? '';
    final String? imageUrl = commentData['imageUrl'] as String?;
    final Timestamp? timestamp = commentData['timestamp'] as Timestamp?;
    final bool isOwn = senderId == _currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: senderId.isNotEmpty && !isOwn
                        ? () async {
                            final profile = await _profileService.getProfile(senderId);
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => UserViewPage(
                                    userId: senderId,
                                    userEmail: profile?.email ?? '',
                                  ),
                                ),
                              );
                            }
                          }
                        : null,
                    child: Row(
                      children: [
                        Text(senderDisplayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(width: 8),
                        Text(_formatTimestamp(timestamp), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
                    ),
                  ),
                ),
                if (isOwn)
                  PopupMenuButton<String>(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    onSelected: (value) {
                      if (value == 'edit') _editComment(commentId, commentText, imageUrl);
                      if (value == 'delete') _deleteComment(commentId);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Szerkesztés')])),
                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Törlés', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
              ],
            ),
            if (commentText.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(commentText, style: const TextStyle(fontSize: 14)),
            ],
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullscreenImagePage(imageUrl: imageUrl))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 60,
                      child: Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Poszt')),
        body: const Center(child: Text('Hiba: Nincs bejelentkezett felhasználó.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Poszt')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore.collection('posts').doc(widget.postId).snapshots(),
              builder: (context, postSnap) {
                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('posts')
                      .doc(widget.postId)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, commentsSnap) {
                    final List<Widget> slivers = [];

                    if (!postSnap.hasData || !postSnap.data!.exists) {
                      slivers.add(const SliverToBoxAdapter(
                        child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                      ));
                    } else {
                      final data = postSnap.data!.data() as Map<String, dynamic>;
                      slivers.add(SliverToBoxAdapter(child: _buildPostCard(data)));
                    }

                    slivers.add(const SliverToBoxAdapter(child: Divider(height: 1)));

                    if (commentsSnap.connectionState == ConnectionState.waiting) {
                      slivers.add(const SliverToBoxAdapter(
                        child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                      ));
                    } else if (commentsSnap.hasError) {
                      slivers.add(SliverToBoxAdapter(
                        child: Center(child: Text('Hiba: ${commentsSnap.error}')),
                      ));
                    } else if (!commentsSnap.hasData || commentsSnap.data!.docs.isEmpty) {
                      slivers.add(const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: Text('Még nincs komment. Légy te az első!')),
                        ),
                      ));
                    } else {
                      slivers.add(SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final doc = commentsSnap.data!.docs[index];
                            final commentData = doc.data() as Map<String, dynamic>;
                            return _buildCommentItem(commentData, doc.id);
                          },
                          childCount: commentsSnap.data!.docs.length,
                        ),
                      ));
                    }

                    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 8)));

                    return CustomScrollView(slivers: slivers);
                  },
                );
              },
            ),
          ),
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
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isSending
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                          onPressed: _addComment,
                          icon: const Icon(Icons.send),
                          color: Theme.of(context).primaryColor,
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
