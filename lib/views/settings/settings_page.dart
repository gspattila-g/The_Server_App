import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart'; // <<< JAVÍTVA: Relatív útvonal a providers mappához

/// A beállítások oldal widgetje.
///
/// Lehetővé teszi a felhasználó számára a sötét mód és az értesítések
/// be- és kikapcsolását.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Beállítások'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Sötét mód kapcsoló
            _buildSwitchTile( // JAVÍTVA: _buildSwitchTile hívása
              context: context,
              title: 'Sötét mód',
              value: settingsProvider.isDarkMode,
              onChanged: (val) {
                settingsProvider.toggleTheme(val);
              },
            ),
            // Értesítések kapcsoló
            _buildSwitchTile( // JAVÍTVA: _buildSwitchTile hívása
              context: context,
              title: 'Értesítések',
              value: settingsProvider.notificationsEnabled,
              onChanged: (val) {
                settingsProvider.toggleNotifications(val);
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
