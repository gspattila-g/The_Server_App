import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Szolgáltatás az üzenetek és chat szobák Firebase Firestore-ban való kezeléséhez.
///
/// Ez az osztály biztosítja a metódusokat az üzenetek küldéséhez,
/// a chat szobák azonosítóinak generálásához és az üzenetek valós idejű
/// streameléséhez egy adott chat szobán belül.
class ChatService {
  // A Firestore adatbázis példánya. Ezen keresztül érjük el a Firestore szolgáltatást.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Generálja egy chat szoba azonosítóját két felhasználó UID-je alapján.
  ///
  /// A két UID-t alfabetikusan rendezi, majd aláhúzással (_) fűzi össze,
  /// így biztosítva, hogy a chat szoba ID-je konzisztens legyen,
  /// függetlenül attól, hogy ki indítja a beszélgetést.
  /// Például: ha user1Id = "abc" és user2Id = "xyz", akkor az ID "abc_xyz" lesz.
  /// Ha user1Id = "xyz" és user2Id = "abc", akkor is "abc_xyz" lesz az ID.
  String getChatRoomId(String user1Id, String user2Id) {
    List<String> ids = [user1Id, user2Id];
    ids.sort(); // Alfabetikus rendezés a konzisztencia érdekében
    return ids.join('_'); // Összefűzés aláhúzással
  }

  /// Üzenet küldése egy adott chat szobába.
  ///
  /// [receiverId] annak a felhasználónak az UID-je, akinek az üzenetet küldjük.
  /// [message] az elküldendő üzenet szövege.
  ///
  /// Ez a metódus:
  /// 1. Ellenőrzi, hogy van-e bejelentkezett felhasználó.
  /// 2. Létrehozza a chat szoba azonosítóját a `getChatRoomId` metódussal.
  /// 3. Összeállítja az üzenet adatait egy `Map` formátumban, beleértve a
  ///    küldő és fogadó azonosítóját, az üzenet szövegét, és egy szerveroldali időbélyeget.
  /// 4. Hozzáadja az üzenetet a Firestore megfelelő chat szoba 'messages' alkollekciójához.
  Future<void> sendMessage(String receiverId, String message, {String? senderDisplayName, String? imageUrl}) async {
    final String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw Exception('Nincs bejelentkezett felhasználó.');

    final String chatRoomId = getChatRoomId(currentUserId, receiverId);
    final chatRoomRef = _firestore.collection('chats').doc(chatRoomId);

    final messageData = {
      'senderId': currentUserId,
      'senderName': senderDisplayName ?? _auth.currentUser?.email ?? 'Ismeretlen',
      'receiverId': receiverId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
      if (imageUrl != null) 'imageUrl': imageUrl,
    };

    await chatRoomRef.collection('messages').add(messageData);

    final displayMessage = imageUrl != null && message.isEmpty ? '📷 Kép' : message;

    // Top-level mező: 'unread_<uid>' – megbízható increment set()+merge:true-val
    await chatRoomRef.set({
      'participants': [currentUserId, receiverId],
      'lastMessage': displayMessage,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': currentUserId,
      'unread_$receiverId': FieldValue.increment(1),
    }, SetOptions(merge: true));

  }

  Stream<QuerySnapshot> getUserChats(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  Future<void> backfillExistingChats(String currentUserId) async {
    final friendsDoc = await _firestore.collection('friends').doc(currentUserId).get();
    final friendIds = List<String>.from(friendsDoc.data()?['friendIds'] ?? []);

    for (final friendId in friendIds) {
      final chatRoomId = getChatRoomId(currentUserId, friendId);
      final chatDoc = await _firestore.collection('chats').doc(chatRoomId).get();

      if (chatDoc.data()?['participants'] == null) {
        final lastMsgSnap = await _firestore
            .collection('chats')
            .doc(chatRoomId)
            .collection('messages')
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        if (lastMsgSnap.docs.isNotEmpty) {
          final lastMsg = lastMsgSnap.docs.first.data();
          await _firestore.collection('chats').doc(chatRoomId).set({
            'participants': [currentUserId, friendId],
            'lastMessage': lastMsg['message'] ?? '',
            'lastMessageTime': lastMsg['timestamp'],
            'lastMessageSenderId': lastMsg['senderId'] ?? '',
          }, SetOptions(merge: true));
        }
      }
    }
  }

  /// Streamet biztosít az üzenetek valós idejű figyeléséhez egy adott chat szobában.
  ///
  /// [chatRoomId] annak a chat szobának az azonosítója, amelynek üzeneteit streamelni szeretnénk.
  ///
  /// Ez a metódus egy `Stream<QuerySnapshot>`-ot ad vissza, ami azt jelenti,
  /// hogy bármikor, amikor új üzenet érkezik, vagy egy meglévő üzenet módosul (bár ez chatnél ritka),
  /// a stream értesíti a hallgatókat (pl. a `ChatPage` widgetet),
  /// és az adatok frissülnek a felhasználói felületen.
  ///
  /// Az üzeneteket időbélyeg (timestamp) szerint, növekvő sorrendben (legrégebbi elől)
  /// adja vissza, ami ideális a chat felületekhez. A `ChatPage` widgetben ezt
  /// fordítva jelenítjük meg, hogy a legújabb üzenetek legyenek alul.
  Stream<QuerySnapshot> getMessages(String chatRoomId) {
    return _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false) // Üzenetek rendezése időbélyeg szerint, növekvő sorrendben (legrégebbi elől)
        .snapshots(); // A `snapshots()` metódus biztosítja a valós idejű frissítéseket
  }

  Stream<DocumentSnapshot> getChatRoomStream(String chatRoomId) {
    return _firestore.collection('chats').doc(chatRoomId).snapshots();
  }

  Future<void> markAsRead(String chatRoomId, String userId) async {
    final ref = _firestore.collection('chats').doc(chatRoomId);
    await ref.set({
      'readBy': {userId: FieldValue.serverTimestamp()},
      'unread_$userId': 0,
    }, SetOptions(merge: true));
  }

  Stream<int> getTotalUnreadStream(String userId) {
    return getUserChats(userId).map((snapshot) {
      int total = 0;
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        total += (data['unread_$userId'] as num? ?? 0).toInt();
      }
      return total;
    });
  }
}
