import 'package:flutter/material.dart';

class MorePage extends StatelessWidget {
  final VoidCallback onUsersSelected;
  final VoidCallback onGamesSelected;
  final VoidCallback onSettingsSelected;

  const MorePage({
    super.key,
    required this.onUsersSelected,
    required this.onGamesSelected,
    required this.onSettingsSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Felhasználók'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onUsersSelected,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.games),
            title: const Text('Játékok'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onGamesSelected,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Beállítások'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: onSettingsSelected,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
