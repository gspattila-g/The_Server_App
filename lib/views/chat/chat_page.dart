import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/chat_service.dart';
import '../../models/user_profile.dart';
import '../../services/profile_service.dart';
import '../../widgets/status_dot.dart';
import '../../widgets/fullscreen_image_page.dart';
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
  File? _selectedImage;
  bool _isSending = false;
  final ImagePicker _picker = ImagePicker();

  // A chat szoba ID-je
  late String _chatRoomId;

  // A fogadó felhasználó profilja (pl. a megjelenítendő névhez)
  UserProfile? _receiverProfile;

  // Vezérlő a ListView görgetéséhez, hogy mindig az utolsó üzenet látszódjon.
  final ScrollController _scrollController = ScrollController();

  // Stable stream references (must not recreate on every build)
  late Stream<QuerySnapshot> _messagesStream;
  late Stream<DocumentSnapshot> _chatRoomStream;

  // Receiver's last-read timestamp, updated by the room stream listener
  Timestamp? _receiverReadAt;

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

    _messagesStream = _chatService.getMessages(_chatRoomId);
    _chatRoomStream = _chatService.getChatRoomStream(_chatRoomId);

    _loadProfiles();
    _chatService.markAsRead(_chatRoomId, _currentUser!.uid);
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

  Future<void> _pickImage() async {
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (picked != null) setState(() => _selectedImage = File(picked.path));
  }

  Future<String?> _uploadImage(File image) async {
    final uid = _currentUser?.uid;
    if (uid == null) return null;
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_$uid.jpg';
    final ref = FirebaseStorage.instance.ref().child('chat_images').child(fileName);
    await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  /// Üzenet elküldése.
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;
    setState(() => _isSending = true);
    try {
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = await _uploadImage(_selectedImage!);
      }
      await _chatService.sendMessage(
        widget.receiverUserId,
        text,
        senderDisplayName: _currentUserDisplayName,
        imageUrl: imageUrl,
      );
      _messageController.clear();
      setState(() => _selectedImage = null);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hiba az üzenet küldésekor: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildMessageItem(Map<String, dynamic> messageData, {bool isLastSentByMe = false, bool isRead = false}) {
    final bool isMe = messageData['senderId'] == _currentUser?.uid;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleColor = isMe
        ? theme.colorScheme.primary
        : (isDark ? Colors.grey[800]! : Colors.grey[200]!);
    final textColor = isMe ? Colors.white : theme.colorScheme.onSurface;
    final subColor = isMe ? Colors.white.withOpacity(0.65) : theme.colorScheme.onSurface.withOpacity(0.45);

    final radius = isMe
        ? const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        margin: EdgeInsets.only(
          top: 2, bottom: 2,
          left: isMe ? 56 : 12,
          right: isMe ? 12 : 56,
        ),
        decoration: BoxDecoration(color: bubbleColor, borderRadius: radius),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((messageData['message'] as String? ?? '').isNotEmpty)
              Text(
                messageData['message'] as String,
                style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
              ),
            if (messageData['imageUrl'] != null) ...[
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullscreenImagePage(imageUrl: messageData['imageUrl'] as String),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    messageData['imageUrl'] as String,
                    width: 200,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const SizedBox(width: 200, height: 150, child: Center(child: CircularProgressIndicator())),
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTimestamp(messageData['timestamp'] as Timestamp?),
                  style: TextStyle(fontSize: 10, color: subColor),
                ),
                if (isLastSentByMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 13,
                    color: isRead ? Colors.lightBlueAccent : subColor,
                  ),
                ],
              ],
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
            child: Column(
              children: [
                // Hidden room stream listener — reads receiverReadAt without causing rebuild loops
                StreamBuilder<DocumentSnapshot>(
                  stream: _chatRoomStream,
                  builder: (context, roomSnapshot) {
                    if (roomSnapshot.hasData) {
                      final roomData = roomSnapshot.data!.data() as Map<String, dynamic>?;
                      final readBy = roomData?['readBy'] as Map<String, dynamic>?;
                      final ts = readBy?[widget.receiverUserId] as Timestamp?;
                      if (ts != _receiverReadAt) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _receiverReadAt = ts);
                        });
                      }
                    }
                    return const SizedBox.shrink();
                  },
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _messagesStream,
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

                      final allDocs = snapshot.data!.docs;
                      final uid = _currentUser?.uid ?? '';

                      // Find the document ID of the last message sent by current user
                      String? lastSentDocId;
                      for (int i = allDocs.length - 1; i >= 0; i--) {
                        final data = allDocs[i].data() as Map<String, dynamic>;
                        if (data['senderId'] == uid && uid.isNotEmpty) {
                          lastSentDocId = allDocs[i].id;
                          break;
                        }
                      }

                      final messages = allDocs.reversed.toList();

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final doc = messages[index];
                          final messageData = doc.data() as Map<String, dynamic>;
                          final isLastSent = doc.id == lastSentDocId;

                          bool isRead = false;
                          if (isLastSent && _receiverReadAt != null) {
                            final msgTimestamp = messageData['timestamp'] as Timestamp?;
                            isRead = msgTimestamp != null &&
                                !_receiverReadAt!.toDate().isBefore(msgTimestamp.toDate());
                          }

                          return _buildMessageItem(messageData, isLastSentByMe: isLastSent, isRead: isRead);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Kép előnézete küldés előtt
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(_selectedImage!, height: 120, width: 120, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 2, right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(4),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // Üzenet beviteli mező és küldés gomb
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _isSending ? null : _pickImage,
                  icon: Icon(Icons.image_outlined, color: Theme.of(context).colorScheme.primary),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isSending,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Üzenet...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[800]
                          : Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _isSending
                    ? const SizedBox(width: 44, height: 44, child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))
                    : Material(
                        color: Theme.of(context).colorScheme.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _sendMessage,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
