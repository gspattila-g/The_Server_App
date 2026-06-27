import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/notification_service.dart';
import '../../models/notification.dart';
import '../../services/profile_service.dart';
import '../comments/comments_page.dart';
import '../chat/chat_page.dart';

/// Értesítések oldal widgetje.
///
/// Ez az oldal felelős a felhasználó bejövő értesítéseinek megjelenítéséért.
/// Lehetővé teszi az értesítések olvasottként való megjelölését és törlését.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  final ProfileService _profileService = ProfileService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('Hiba: Nincs bejelentkezett felhasználó.'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Értesítések'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            tooltip: 'Összes olvasottként jelölése',
            onPressed: () async {
              await _notificationService.markAllNotificationsAsRead(_currentUserId!);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Összes értesítés olvasottként megjelölve.')),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _notificationService.getNotificationsForUser(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hiba az értesítések betöltésekor: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Még nincsenek értesítéseid.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return FutureBuilder<String?>(
                future: _profileService.getProfile(notification.senderId).then((profile) => profile?.displayName),
                builder: (context, senderDisplayNameSnapshot) {
                  final senderDisplayName = senderDisplayNameSnapshot.data ?? 'Ismeretlen Felhasználó';
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    elevation: notification.isRead ? 0.5 : 2, // Olvasott esetén kisebb kiemelés
                    color: notification.isRead ? Colors.grey[200] : Theme.of(context).cardColor,
                    child: ListTile(
                      leading: Icon(
                        _getNotificationIcon(notification.type),
                        color: notification.isRead ? Colors.grey : Theme.of(context).primaryColor,
                      ),
                      title: Text(
                        '${notification.message}', // Az üzenet már tartalmazza a nevet
                        style: TextStyle(
                          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                          color: notification.isRead ? Colors.grey[600] : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        _formatTimestamp(notification.timestamp),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!notification.isRead)
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              tooltip: 'Olvasottként jelölés',
                              onPressed: () async {
                                await _notificationService.markNotificationAsRead(notification.id!);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Értesítés olvasottként megjelölve.')),
                                );
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Törlés',
                            onPressed: () async {
                              await _notificationService.deleteNotification(notification.id!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Értesítés törölve.')),
                              );
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!notification.isRead) {
                          _notificationService.markNotificationAsRead(notification.id!);
                        }
                        _navigateTo(context, notification);
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _navigateTo(BuildContext context, AppNotification notification) async {
    final type = notification.type;
    final eventId = notification.eventId ?? '';

    if (type == 'like' || type == 'post_like' || type == 'comment') {
      if (eventId.isEmpty) return;
      try {
        final postDoc = await FirebaseFirestore.instance.collection('posts').doc(eventId).get();
        if (!postDoc.exists || !context.mounted) return;
        final data = postDoc.data()!;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => CommentsPage(
            postId: eventId,
            postMessage: data['message'] as String? ?? '',
            postSenderId: data['senderId'] as String? ?? '',
            postSenderDisplayName: data['senderDisplayName'] as String? ?? '',
          ),
        ));
      } catch (_) {}
    } else if (type == 'message') {
      final profile = await _profileService.getProfile(notification.senderId);
      if (!context.mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ChatPage(
          receiverUserId: notification.senderId,
          receiverUserEmail: profile?.email ?? '',
        ),
      ));
    }
  }

  /// Segédmetódus az értesítés típusához tartozó ikon visszaadására.
  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'friend_request':
        return Icons.person_add;
      case 'friend_request_accepted':
        return Icons.people;
      case 'message':
        return Icons.chat;
      case 'post_like':
        return Icons.favorite;
      case 'new_post':
        return Icons.campaign;
      default:
        return Icons.info;
    }
  }

  /// Időbélyeg formázása olvasható stringgé.
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'néhány másodperce';
    if (difference.inMinutes < 60) return '${difference.inMinutes} perce';
    if (difference.inHours < 24) return '${difference.inHours} órája';
    return '${date.year}.${date.month}.${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
