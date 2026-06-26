import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';

import '../settings/settings_page.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';

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
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba a kijelentkezéskor: $e')),
        );
      }
    }
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
                const SizedBox(height: 10),
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
              ],
            ),
          );
        },
      ),
    );
  }
}