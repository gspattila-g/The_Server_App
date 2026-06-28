import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/chat_service.dart';
import '../../services/profile_service.dart';
import '../../models/user_profile.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/status_dot.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final _chatService = ChatService();
  final _profileService = ProfileService();
  final _profileCache = <String, UserProfile>{};
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final _searchController = TextEditingController();
  bool _backfillDone = false;
  String _searchQuery = '';
  // utolsó kész lista – megmutatjuk amíg az új betölt
  List<_ChatItem> _lastItems = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _runBackfill();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _runBackfill() async {
    if (_currentUserId == null) return;
    await _chatService.backfillExistingChats(_currentUserId!);
    if (mounted) setState(() => _backfillDone = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return const Center(child: Text('Nincs bejelentkezett felhasználó.'));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Üzenetek'), actions: const [NotificationBell()]),
      body: !_backfillDone
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Keresés...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _chatService.getUserChats(_currentUserId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Hiba: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'Még nincs üzeneted.\nMenj egy felhasználó profiljára és kezdj el chattelni!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final chats = snapshot.data!.docs;

                      return FutureBuilder<List<_ChatItem>>(
                        future: _buildChatItems(chats),
                        builder: (context, itemsSnap) {
                          // Amíg az új adat betölt, az előző lista látszik (nem villan)
                          if (itemsSnap.hasData) {
                            _lastItems = itemsSnap.data!;
                          }

                          final items = _lastItems.where((item) {
                            if (_searchQuery.isEmpty) return true;
                            return item.name.toLowerCase().contains(_searchQuery);
                          }).toList();

                          if (_lastItems.isEmpty && !itemsSnap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (items.isEmpty) {
                            return Center(
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'Még nincs üzeneted.'
                                    : 'Nincs találat: "$_searchQuery"',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final hasUnread = item.unreadCount > 0;
                              return ListTile(
                                tileColor: hasUnread
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.06)
                                    : null,
                                leading: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: item.profile != null
                                          ? StatusDot.colorFor(item.profile!.status)
                                          : Colors.grey,
                                      width: 3,
                                    ),
                                  ),
                                  child: ProfileAvatar(
                                    imageUrl: item.profile?.profileImageUrl,
                                    fallbackLetter: item.name,
                                    radius: 20,
                                  ),
                                ),
                                title: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                                    color: hasUnread ? Theme.of(context).colorScheme.primary : null,
                                  ),
                                ),
                                subtitle: Text(
                                  item.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: hasUnread ? Colors.black87 : Colors.grey,
                                    fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (hasUnread)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${item.unreadCount}',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    if (item.lastTime != null) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatTime(item.lastTime!),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(
                                      receiverUserId: item.otherUserId,
                                      receiverUserEmail: item.profile?.email ?? '',
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
                ),
              ],
            ),
    );
  }

  Future<List<_ChatItem>> _buildChatItems(List<QueryDocumentSnapshot> chats) async {
    final items = <_ChatItem>[];
    for (final doc in chats) {
      final data = doc.data() as Map<String, dynamic>;
      final participants = List<String>.from(data['participants'] ?? []);
      final otherUserId = participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );
      if (otherUserId.isEmpty) continue;

      UserProfile? profile;
      if (_profileCache.containsKey(otherUserId)) {
        profile = _profileCache[otherUserId];
      } else {
        profile = await _profileService.getProfile(otherUserId);
        if (profile != null) _profileCache[otherUserId] = profile;
      }

      final unreadCount = (data['unread_$_currentUserId'] as num? ?? 0).toInt();

      items.add(_ChatItem(
        otherUserId: otherUserId,
        profile: profile,
        name: profile?.displayName ?? otherUserId,
        lastMessage: data['lastMessage'] as String? ?? '',
        lastTime: data['lastMessageTime'] as Timestamp?,
        unreadCount: unreadCount,
      ));
    }
    return items;
  }

  String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'most';
    if (diff.inMinutes < 60) return '${diff.inMinutes} perce';
    if (diff.inHours < 24) return '${diff.inHours} órája';
    return '${date.month}.${date.day}';
  }
}

class _ChatItem {
  final String otherUserId;
  final UserProfile? profile;
  final String name;
  final String lastMessage;
  final Timestamp? lastTime;
  final int unreadCount;

  const _ChatItem({
    required this.otherUserId,
    required this.profile,
    required this.name,
    required this.lastMessage,
    required this.lastTime,
    this.unreadCount = 0,
  });
}
