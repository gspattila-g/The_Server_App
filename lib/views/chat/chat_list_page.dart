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
  bool _backfillDone = false;

  @override
  void initState() {
    super.initState();
    _runBackfill();
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
          : StreamBuilder<QuerySnapshot>(
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

                return ListView.separated(
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = chats[index].data() as Map<String, dynamic>;
                    final participants = List<String>.from(data['participants'] ?? []);
                    final otherUserId = participants.firstWhere(
                      (id) => id != _currentUserId,
                      orElse: () => '',
                    );
                    if (otherUserId.isEmpty) return const SizedBox.shrink();

                    final lastMessage = data['lastMessage'] as String? ?? '';
                    final lastTime = data['lastMessageTime'] as Timestamp?;

                    return FutureBuilder<UserProfile?>(
                      future: _profileCache.containsKey(otherUserId)
                          ? Future.value(_profileCache[otherUserId])
                          : _profileService.getProfile(otherUserId).then((p) {
                              if (p != null) _profileCache[otherUserId] = p;
                              return p;
                            }),
                      builder: (context, profileSnap) {
                        final profile = profileSnap.data;
                        final name = profile?.displayName ?? otherUserId;
                        final email = profile?.email ?? '';

                        return ListTile(
                          leading: ProfileAvatar(
                            imageUrl: profile?.profileImageUrl,
                            fallbackLetter: name,
                            radius: 24,
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: lastTime != null
                              ? Text(
                                  _formatTime(lastTime),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                )
                              : null,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                receiverUserId: otherUserId,
                                receiverUserEmail: email,
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
    );
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
