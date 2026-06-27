import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/chat_service.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../widgets/status_dot.dart';
import '../users/user_view_page.dart';

/// A chat felület, ahol a felhasználók üzeneteket válthatnak egymással.
///
/// Egy adott felhasználóval való beszélgetést kezel.
class ChatPage extends StatefulWidget {
  final String receiverUserId;   // Annak a felhasználónak az UID-je, akivel beszélgetünk
  final String receiverUserEmail; // Annak a felhasználónak az email címe (felhasználói felületen való megjelenítéshez)

  ChatPage({
    super.key,
    required this.receiverUserId,
    required this.receiverUserEmail,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final ProfileService _profileService = ProfileService(); // Szükséges a felhasználó nevének lekéréséhez

  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String? _currentUserDisplayName;

  // A chat szoba ID-je
  late String _chatRoomId;

  // A fogadó felhasználó profilja (pl. a megjelenítendő névhez)
  UserProfile? _receiverProfile;

  // Vezérlő a ListView görgetéséhez, hogy mindig az utolsó üzenet látszódjon.
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Ellenőrizzük, hogy van-e bejelentkezett felhasználó.
    if (_currentUser == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hiba: Nincs bejelentkezett felhasználó a chat indításához.')),
        );
        Navigator.pop(context); // Vissza a korábbi oldalra
      });
      return;
    }

    // Generáljuk a chat szoba ID-jét a jelenlegi és a fogadó felhasználó UID-jei alapján.
    _chatRoomId = _chatService.getChatRoomId(_currentUser!.uid, widget.receiverUserId);

    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    try {
      final results = await Future.wait([
        _profileService.getProfile(widget.receiverUserId),
        if (_currentUser != null) _profileService.getProfile(_currentUser!.uid),
      ]);
      if (mounted) {
        setState(() {
          _receiverProfile = results[0];
          if (results.length > 1) _currentUserDisplayName = results[1]?.displayName;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba: $e')),
        );
      }
    }
  }

  /// Üzenet elküldése.
  Future<void> _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      try {
        await _chatService.sendMessage(
          widget.receiverUserId,
          _messageController.text.trim(),
          senderDisplayName: _currentUserDisplayName,
        );
        _messageController.clear(); // Üzenet elküldése után töröljük a beviteli mezőt
        // Görgetés az utolsó üzenetre
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0.0, // A ListView reverse:true miatt 0.0 az alja (legújabb üzenet)
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba az üzenet küldésekor: $e')),
        );
      }
    }
  }

  /// Üzenetbuborék építése a chaten belül.
  ///
  /// [messageData] az üzenet Firestore adatait tartalmazó Map.
  Widget _buildMessageItem(Map<String, dynamic> messageData) {
    // Ellenőrizzük, hogy a jelenlegi felhasználó a küldő.
    final bool isCurrentUser = messageData['senderId'] == _currentUser!.uid;

    return Align(
      // Igazítjuk a buborékot attól függően, hogy ki küldte az üzenetet.
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        decoration: BoxDecoration(
          color: isCurrentUser ? Colors.deepPurple[100] : Colors.grey[300],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              messageData['senderName'] ?? messageData['senderEmail'] ?? 'Ismeretlen',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCurrentUser ? Colors.deepPurple[800] : Colors.grey[700],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            // Az üzenet szövege
            Text(
              messageData['message'],
              style: TextStyle(
                color: isCurrentUser ? Colors.deepPurple[900] : Colors.grey[900],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            // Időbélyeg (timestamp) formázva
            Text(
              _formatTimestamp(messageData['timestamp'] as Timestamp?),
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  /// Időbélyeg formázása olvasható stringgé.
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Nincs időpont';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'néhány másodperce';
    if (difference.inMinutes < 60) return '${difference.inMinutes} perce';
    if (difference.inHours < 24) return '${difference.inHours} órája';
    // Módosítás: Óra és perc is kétjegyű legyen a konzisztencia érdekében
    return '${date.year}.${date.month}.${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose(); // Fontos: a görgetésvezérlőt is el kell dobni
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ha nincs bejelentkezett felhasználó, vagy még töltjük a fogadó profilját.
    if (_currentUser == null || _receiverProfile == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserViewPage(
                userId: widget.receiverUserId,
                userEmail: widget.receiverUserEmail,
              ),
            ),
          ),
          child: StreamBuilder<UserProfile?>(
            stream: _profileService.getProfileStream(widget.receiverUserId),
            builder: (context, snapshot) {
              final profile = snapshot.data ?? _receiverProfile;
              final status = profile?.status ?? 'offline';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(profile?.displayName ?? widget.receiverUserEmail),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: StatusDot.colorFor(status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        StatusDot.labelFor(status),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
      body: Column(
        children: [
          // Üzenetek listája
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(_chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Hiba az üzenetek betöltésekor: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Még nincs üzenet. Kezdj el beszélgetni!'));
                }

                // Üzenetek megjelenítése fordított sorrendben (legújabb alul)
                final messages = snapshot.data!.docs.reversed.toList();

                return ListView.builder(
                  controller: _scrollController, // Hozzáadjuk a görgetésvezérlőt
                  // reverse: true; (legújabb üzenetek alul)
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData = messages[index].data() as Map<String, dynamic>;
                    return _buildMessageItem(messageData);
                  },
                );
              },
            ),
          ),
          // Üzenet beviteli mező és küldés gomb
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Üzenet...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                    ),
                    obscureText: false,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send),
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
