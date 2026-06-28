import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_profile.dart';
import '../../models/notification.dart';
import '../../widgets/profile_avatar.dart';

import '../home/new_post_page.dart';
import '../../services/profile_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/notification_bell.dart';
import '../comments/comments_page.dart';
import '../../widgets/fullscreen_image_page.dart';
import '../users/user_view_page.dart';

class HomePage extends StatefulWidget {
  final String userEmail;

  const HomePage({super.key, required this.userEmail});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProfileService _profileService = ProfileService();
  final NotificationService _notificationService = NotificationService();
  final Map<String, UserProfile> _profileCache = {};
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _addNewPost(BuildContext context, String text, String? imageUrl) async {
    if (_currentUserId == null) return;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Poszt sikeresen közzétéve!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba: $e')));
      }
    }
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

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('Hiba: Nincs bejelentkezett felhasználó azonosító.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Főoldal'),
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.add_box),
            tooltip: 'Új poszt',
            onPressed: () async {
              final result = await Navigator.push<Map<String, dynamic?>>(
                context,
                MaterialPageRoute(builder: (context) => const NewPostPage()),
              );
              if (result != null && mounted) {
                final text = (result['text'] as String?) ?? '';
                final imageUrl = result['imageUrl'] as String?;
                _addNewPost(context, text, imageUrl);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Barátok'),
            Tab(icon: Icon(Icons.explore), text: 'Felfedezés'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FriendsTab(
            currentUserId: _currentUserId!,
            firestore: _firestore,
            profileCache: _profileCache,
            profileService: _profileService,
            onToggleLike: _toggleLike,
          ),
          _AllPostsTab(
            currentUserId: _currentUserId!,
            firestore: _firestore,
            profileCache: _profileCache,
            profileService: _profileService,
            onToggleLike: _toggleLike,
          ),
        ],
      ),
    );
  }
}

// --- Barátok tab ---

class _FriendsTab extends StatelessWidget {
  final String currentUserId;
  final FirebaseFirestore firestore;
  final Map<String, UserProfile> profileCache;
  final ProfileService profileService;
  final Future<void> Function(String, List<dynamic>, String) onToggleLike;

  const _FriendsTab({
    required this.currentUserId,
    required this.firestore,
    required this.profileCache,
    required this.profileService,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: firestore.collection('friends').doc(currentUserId).snapshots(),
      builder: (context, friendsSnap) {
        if (friendsSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = friendsSnap.data?.data() as Map<String, dynamic>?;
        final friendIds = (data?['friendIds'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [];

        if (friendIds.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Még nincsenek barátaid.\nA Felfedezés fülön ismerhetsz meg más játékosokat!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        }

        // Firestore whereIn max 30 elemig működik
        final queryIds = friendIds.take(30).toList();

        return StreamBuilder<QuerySnapshot>(
          stream: firestore
              .collection('posts')
              .where('senderId', whereIn: queryIds)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'A barátaid még nem posztoltak semmit.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }
            final sortedDocs = snapshot.data!.docs.toList()
              ..sort((a, b) {
                final aTs = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                final bTs = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                if (aTs == null && bTs == null) return 0;
                if (aTs == null) return 1;
                if (bTs == null) return -1;
                return bTs.compareTo(aTs);
              });
            return _PostList(
              posts: sortedDocs,
              currentUserId: currentUserId,
              firestore: firestore,
              profileCache: profileCache,
              profileService: profileService,
              onToggleLike: onToggleLike,
            );
          },
        );
      },
    );
  }
}

// --- Felfedezés tab ---

class _AllPostsTab extends StatelessWidget {
  final String currentUserId;
  final FirebaseFirestore firestore;
  final Map<String, UserProfile> profileCache;
  final ProfileService profileService;
  final Future<void> Function(String, List<dynamic>, String) onToggleLike;

  const _AllPostsTab({
    required this.currentUserId,
    required this.firestore,
    required this.profileCache,
    required this.profileService,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('posts').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text(
              'Még nincsenek posztok. Légy te az első!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }
        return _PostList(
          posts: snapshot.data!.docs,
          currentUserId: currentUserId,
          firestore: firestore,
          profileCache: profileCache,
          profileService: profileService,
          onToggleLike: onToggleLike,
        );
      },
    );
  }
}

// --- Közös poszt lista widget ---

class _PostList extends StatelessWidget {
  final List<DocumentSnapshot> posts;
  final String currentUserId;
  final FirebaseFirestore firestore;
  final Map<String, UserProfile> profileCache;
  final ProfileService profileService;
  final Future<void> Function(String, List<dynamic>, String) onToggleLike;

  const _PostList({
    required this.posts,
    required this.currentUserId,
    required this.firestore,
    required this.profileCache,
    required this.profileService,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: posts.length,
      itemBuilder: (context, index) => _PostCard(
        post: posts[index],
        currentUserId: currentUserId,
        firestore: firestore,
        profileCache: profileCache,
        profileService: profileService,
        onToggleLike: onToggleLike,
      ),
    );
  }
}

// --- Poszt kártya widget ---

class _PostCard extends StatelessWidget {
  final DocumentSnapshot post;
  final String currentUserId;
  final FirebaseFirestore firestore;
  final Map<String, UserProfile> profileCache;
  final ProfileService profileService;
  final Future<void> Function(String, List<dynamic>, String) onToggleLike;

  const _PostCard({
    required this.post,
    required this.currentUserId,
    required this.firestore,
    required this.profileCache,
    required this.profileService,
    required this.onToggleLike,
  });

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inSeconds < 60) return 'néhány másodperce';
    if (difference.inMinutes < 60) return '${difference.inMinutes} perce';
    if (difference.inHours < 24) return '${difference.inHours} órája';
    return '${date.year}.${date.month}.${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showDeleteDialog(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Poszt törlése'),
        content: const Text('Biztosan törölni szeretnéd ezt a posztot? A törlés nem vonható vissza.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Mégse'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await firestore.collection('posts').doc(postId).delete();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, String postId, String currentMessage, String? currentImageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => _EditPostDialog(
        postId: postId,
        currentMessage: currentMessage,
        currentImageUrl: currentImageUrl,
        firestore: firestore,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = post.data() as Map<String, dynamic>;
    final postId = post.id;
    final message = data['message'] ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final senderId = data['senderId'] ?? '';
    final timestamp = data['timestamp'] as Timestamp? ?? Timestamp.now();
    final likes = data['likes'] as List<dynamic>? ?? [];
    final isLiked = likes.contains(currentUserId);

    return FutureBuilder<UserProfile?>(
      future: profileCache.containsKey(senderId)
          ? Future.value(profileCache[senderId])
          : profileService.getProfile(senderId).then((p) {
              if (p != null) profileCache[senderId] = p;
              return p;
            }),
      builder: (context, profileSnap) {
        final displayName = profileSnap.data?.displayName ?? data['senderDisplayName'] ?? 'Ismeretlen';
        final profileImageUrl = profileSnap.data?.profileImageUrl;

        return StreamBuilder<QuerySnapshot>(
          stream: firestore.collection('posts').doc(postId).collection('comments').snapshots(),
          builder: (context, commentSnap) {
            final commentCount = commentSnap.data?.docs.length ?? 0;

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: senderId != currentUserId
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UserViewPage(
                                          userId: senderId,
                                          userEmail: profileSnap.data?.email ?? '',
                                        ),
                                      ),
                                    )
                                : null,
                            child: Row(
                              children: [
                                ProfileAvatar(imageUrl: profileImageUrl, fallbackLetter: displayName, radius: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      Text(_formatTimestamp(timestamp), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (senderId == currentUserId)
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _showEditDialog(context, postId, message, imageUrl);
                              if (value == 'delete') _showDeleteDialog(context, postId);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Szerkesztés')]),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Törlés', style: TextStyle(color: Colors.red))]),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CommentsPage(
                            postId: postId,
                            postMessage: message,
                            postSenderId: senderId,
                            postSenderDisplayName: displayName,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.isNotEmpty) Text(message, style: const TextStyle(fontSize: 16)),
                          if (imageUrl != null && imageUrl.isNotEmpty) ...[
                            if (message.isNotEmpty) const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FullscreenImagePage(imageUrl: imageUrl),
                                ),
                              ),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : Colors.grey),
                          onPressed: () => onToggleLike(postId, likes, senderId),
                        ),
                        Text('${likes.length} lájk', style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 20),
                        IconButton(
                          icon: const Icon(Icons.comment),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CommentsPage(
                                postId: postId,
                                postMessage: message,
                                postSenderId: senderId,
                                postSenderDisplayName: displayName,
                              ),
                            ),
                          ),
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
}

// --- Poszt szerkesztő dialóg képkezeléssel ---

class _EditPostDialog extends StatefulWidget {
  final String postId;
  final String currentMessage;
  final String? currentImageUrl;
  final FirebaseFirestore firestore;

  const _EditPostDialog({
    required this.postId,
    required this.currentMessage,
    required this.currentImageUrl,
    required this.firestore,
  });

  @override
  State<_EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<_EditPostDialog> {
  late final TextEditingController _controller;
  final ImagePicker _picker = ImagePicker();

  File? _newImage;
  bool _removeExistingImage = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentMessage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<String?> _uploadImage(File image) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$uid.jpg';
    final ref = FirebaseStorage.instance.ref().child('post_images').child(fileName);
    await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galéria'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1080);
                if (picked != null && mounted) {
                  setState(() { _newImage = File(picked.path); _removeExistingImage = false; });
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () async {
                Navigator.pop(ctx);
                final picked = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1080);
                if (picked != null && mounted) {
                  setState(() { _newImage = File(picked.path); _removeExistingImage = false; });
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    final bool willHaveImage = _newImage != null ||
        (widget.currentImageUrl != null && !_removeExistingImage);
    if (text.isEmpty && !willHaveImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A poszt nem lehet teljesen üres.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? finalImageUrl;
      if (_newImage != null) {
        finalImageUrl = await _uploadImage(_newImage!);
      } else if (_removeExistingImage) {
        finalImageUrl = null;
      } else {
        finalImageUrl = widget.currentImageUrl;
      }

      await widget.firestore.collection('posts').doc(widget.postId).update({
        'message': text,
        'imageUrl': finalImageUrl,
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hiba: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool showExistingImage = widget.currentImageUrl != null && !_removeExistingImage && _newImage == null;
    final bool hasAnyImage = showExistingImage || _newImage != null;

    return AlertDialog(
      title: const Text('Poszt szerkesztése'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              maxLines: 5,
              enabled: !_isUploading,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Poszt szövege...'),
            ),
            const SizedBox(height: 12),
            if (_newImage != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_newImage!, height: 180, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: _isUploading ? null : () => setState(() => _newImage = null),
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
            ] else if (showExistingImage) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(widget.currentImageUrl!, height: 180, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: _isUploading ? null : () => setState(() => _removeExistingImage = true),
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
              onPressed: _isUploading ? null : _showImageSourceSheet,
              icon: const Icon(Icons.image),
              label: Text(hasAnyImage ? 'Kép cseréje' : 'Kép hozzáadása'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('Mégse'),
        ),
        if (_isUploading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else
          ElevatedButton(
            onPressed: _save,
            child: const Text('Mentés'),
          ),
      ],
    );
  }
}
