import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../settings/settings_page.dart';
import '../comments/comments_page.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/status_dot.dart';

class ProfilePage extends StatefulWidget {
  final String email;

  const ProfilePage({
    super.key,
    required this.email,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final ImagePicker _picker = ImagePicker();
  final ProfileService _profileService = ProfileService();

  User? _currentUser;

  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _favoriteGameController = TextEditingController();

  UserProfile? _userProfile;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      _profileService.getProfileStream(_currentUser!.uid).listen((profile) {
        if (mounted) {
          setState(() {
            _userProfile = profile;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _favoriteGameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadProfileImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (image == null || _currentUser == null || _userProfile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final imageUrl = await _profileService.uploadProfileImage(
        _currentUser!.uid,
        File(image.path),
      );

      final updatedProfile = _userProfile!.copyWith(profileImageUrl: imageUrl);
      await _profileService.updateProfile(updatedProfile);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profilkép sikeresen frissítve!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a profilkép feltöltésekor: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_currentUser == null || _userProfile == null) return;

    final updatedProfile = UserProfile(
      uid: _userProfile!.uid,
      email: _userProfile!.email,
      displayName: _displayNameController.text.trim(),
      bio: _bioController.text.trim(),
      favoriteGame: _favoriteGameController.text.trim(),
      profileImageUrl: _userProfile!.profileImageUrl,
    );

    try {
      await _profileService.updateProfile(updatedProfile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil sikeresen mentve!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a profil mentésekor: $e')),
        );
      }
    }
  }

  Future<void> _signOut() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _profileService.setStatus(uid, 'offline');
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a kijelentkezéskor: $e')),
        );
      }
    }
  }

  Widget _buildStatColumn(int count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'néhány másodperce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} perce';
    if (diff.inHours < 24) return '${diff.inHours} órája';
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  Widget _buildProfileAvatar() {
    return GestureDetector(
      onTap: _isUploadingImage ? null : _pickAndUploadProfileImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            backgroundImage: _userProfile?.profileImageUrl != null
                ? NetworkImage(_userProfile!.profileImageUrl!)
                : null,
            child: _userProfile?.profileImageUrl == null
                ? Icon(
              Icons.camera_alt,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            )
                : null,
          ),
          if (_isUploadingImage)
            Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilom'),
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Beállítások',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: _currentUser == null
          ? const Center(child: Text('Nincs bejelentkezett felhasználó.'))
          : StreamBuilder<UserProfile?>(
        stream: _profileService.getProfileStream(_currentUser!.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hiba: ${snapshot.error}'));
          }

          _userProfile = snapshot.data;

          if (_userProfile == null) {
            _displayNameController.text = '';
            _bioController.text = '';
            _favoriteGameController.text = '';
          } else {
            if (_displayNameController.text != _userProfile!.displayName) {
              _displayNameController.text = _userProfile!.displayName;
            }
            if (_bioController.text != _userProfile!.bio) {
              _bioController.text = _userProfile!.bio;
            }
            if (_favoriteGameController.text != _userProfile!.favoriteGame) {
              _favoriteGameController.text = _userProfile!.favoriteGame;
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildProfileAvatar(),
                const SizedBox(height: 8),
                Text(
                  'Koppints a kép megváltoztatásához',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _userProfile?.displayName ?? 'Nincs megadva név',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                // Státusz toggle
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StatusDot(status: _userProfile?.status ?? 'offline', size: 12),
                    const SizedBox(width: 6),
                    Text(
                      StatusDot.labelFor(_userProfile?.status ?? 'offline'),
                      style: TextStyle(
                        color: StatusDot.colorFor(_userProfile?.status ?? 'offline'),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    PopupMenuButton<String>(
                      tooltip: 'Státusz módosítása',
                      icon: const Icon(Icons.edit, size: 18),
                      onSelected: (value) async {
                        if (_currentUser != null) {
                          await _profileService.setStatus(_currentUser!.uid, value);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'online', child: Row(children: [StatusDot(status: 'online'), const SizedBox(width: 8), const Text('Online')])),
                        PopupMenuItem(value: 'busy', child: Row(children: [StatusDot(status: 'busy'), const SizedBox(width: 8), const Text('Elfoglalt')])),
                        PopupMenuItem(value: 'offline', child: Row(children: [StatusDot(status: 'offline'), const SizedBox(width: 8), const Text('Offline')])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('posts')
                          .where('senderId', isEqualTo: _currentUser!.uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final count = snap.data?.docs.length ?? 0;
                        return _buildStatColumn(count, 'Poszt');
                      },
                    ),
                    Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.4), margin: const EdgeInsets.symmetric(horizontal: 24)),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('friends')
                          .doc(_currentUser!.uid)
                          .snapshots(),
                      builder: (context, snap) {
                        final data = snap.data?.data() as Map<String, dynamic>?;
                        final count = (data?['friendIds'] as List?)?.length ?? 0;
                        return _buildStatColumn(count, 'Barát');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _userProfile?.bio ?? 'Nincs bemutatkozás',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Kedvenc játék: ${_userProfile?.favoriteGame ?? 'Nincs kedvenc játék'}',
                  style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 30),
                Text('Bejelentkezett email: ${widget.email}',
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 20),
                TextField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(labelText: 'Név'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(labelText: 'Bemutatkozás'),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _favoriteGameController,
                  decoration: const InputDecoration(labelText: 'Kedvenc játék'),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _saveProfile,
                  child: const Text('Profil mentése'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(160, 50),
                  ),
                  child: const Text('Kijelentkezés'),
                ),
                const SizedBox(height: 32),
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Posztjaim', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('posts')
                      .where('senderId', isEqualTo: _currentUser!.uid)
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, postSnap) {
                    if (postSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!postSnap.hasData || postSnap.data!.docs.isEmpty) {
                      return const Text('Még nincs posztod.', style: TextStyle(color: Colors.grey));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: postSnap.data!.docs.length,
                      itemBuilder: (context, i) {
                        final doc = postSnap.data!.docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        final message = data['message'] as String? ?? '';
                        final imageUrl = data['imageUrl'] as String?;
                        final timestamp = data['timestamp'] as Timestamp?;
                        final likes = (data['likes'] as List?)?.length ?? 0;
                        final dateStr = timestamp != null ? _formatTimestamp(timestamp) : '';
                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('posts')
                              .doc(doc.id)
                              .collection('comments')
                              .snapshots(),
                          builder: (context, commentSnap) {
                            final commentCount = commentSnap.data?.docs.length ?? 0;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CommentsPage(
                                      postId: doc.id,
                                      postMessage: message,
                                      postSenderId: _currentUser!.uid,
                                      postSenderDisplayName: _userProfile?.displayName ?? '',
                                    ),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (message.isNotEmpty)
                                        Text(message, style: const TextStyle(fontSize: 15)),
                                      if (imageUrl != null) ...[
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.favorite_border, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('$likes lájk', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.comment_outlined, size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text('$commentCount komment', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                          const Spacer(),
                                          Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}