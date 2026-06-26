import 'package:flutter/material.dart';

/// A ChangeNotifier that manages the application's theme mode (dark/light)
/// and notification settings.
///
/// It provides methods to toggle these settings and notifies listeners
/// when the state changes, allowing UI elements to react accordingly
/// without rebuilding the entire widget tree.
class SettingsProvider extends ChangeNotifier {
  // Private internal state for dark mode and notifications.
  bool _isDarkMode = false;
  bool _notificationsEnabled = true;

  /// Getter for the current dark mode status.
  bool get isDarkMode => _isDarkMode;

  /// Getter for the current notifications enabled status.
  bool get notificationsEnabled => _notificationsEnabled;

  /// Toggles the dark mode setting.
  ///
  /// [value] The new value for dark mode (true for dark, false for light).
  void toggleTheme(bool value) {
    _isDarkMode = value;
    // Notify all widgets listening to this provider that the state has changed.
    notifyListeners();
  }

  /// Toggles the notifications enabled setting.
  ///
  /// [value] The new value for notifications (true for enabled, false for disabled).
  void toggleNotifications(bool value) {
    _notificationsEnabled = value;
    // Notify all widgets listening to this provider that the state has changed.
    notifyListeners();
  }
}
