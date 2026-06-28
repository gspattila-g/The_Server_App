import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/notification_bell.dart';
import '../../services/block_service.dart';
import '../../services/profile_service.dart';
import '../../widgets/profile_avatar.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final blockService = BlockService();
    final profileService = ProfileService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beállítások'),
        actions: const [NotificationBell()],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            _buildSwitchTile(
              context: context,
              title: 'Sötét mód',
              value: settingsProvider.isDarkMode,
              onChanged: (val) => settingsProvider.toggleTheme(val),
            ),
            _buildSwitchTile(
              context: context,
              title: 'Értesítések',
              value: settingsProvider.notificationsEnabled,
              onChanged: (val) => settingsProvider.toggleNotifications(val),
            ),
            const Divider(height: 32),
            const Text('Blokkolt felhasználók', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (currentUserId != null)
              StreamBuilder<List<String>>(
                stream: blockService.getBlockedIdsStream(currentUserId),
                builder: (context, snap) {
                  final ids = snap.data ?? [];
                  if (ids.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Nincs blokkolt felhasználó.', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return Column(
                    children: ids.map((uid) => FutureBuilder(
                      future: profileService.getProfile(uid),
                      builder: (context, profileSnap) {
                        final profile = profileSnap.data;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ProfileAvatar(
                            imageUrl: profile?.profileImageUrl,
                            fallbackLetter: profile?.displayName ?? '?',
                            radius: 20,
                          ),
                          title: Text(profile?.displayName ?? uid),
                          trailing: TextButton.icon(
                            onPressed: () async {
                              await blockService.unblockUser(currentUserId, uid);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Felhasználó feloldva.')),
                                );
                              }
                            },
                            icon: const Icon(Icons.lock_open, size: 18),
                            label: const Text('Feloldás'),
                          ),
                        );
                      },
                    )).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Segédmetódus a kapcsolók felépítéséhez
  static Widget _buildSwitchTile({ // <<< HOZZÁADVA: static kulcsszó
    required BuildContext context,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0.0),
      title: Text(title, style: const TextStyle(fontSize: 18)),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }
}
