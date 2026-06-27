import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/chat_service.dart';
import '../../services/profile_service.dart';
import '../../models/user_profile.dart';
import '../../widgets/profile_avatar.dart';
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
      appBar: AppBar(title: const Text('Üzenetek')),
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
                          if (!itemsSnap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final items = itemsSnap.data!.where((item) {
                            if (_searchQuery.isEmpty) return true;
                            return item.name.toLowerCase().contains(_searchQuery);
                          }).toList();

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
                              return ListTile(
                                leading: ProfileAvatar(
                                  imageUrl: item.profile?.profileImageUrl,
                                  fallbackLetter: item.name,
                                  radius: 24,
                                ),
                                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  item.lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                trailing: item.lastTime != null
                                    ? Text(
                                        _formatTime(item.lastTime!),
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      )
                                    : null,
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

      items.add(_ChatItem(
        otherUserId: otherUserId,
        profile: profile,
        name: profile?.displayName ?? otherUserId,
        lastMessage: data['lastMessage'] as String? ?? '',
        lastTime: data['lastMessageTime'] as Timestamp?,
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

  const _ChatItem({
    required this.otherUserId,
    required this.profile,
    required this.name,
    required this.lastMessage,
    required this.lastTime,
  });
}
