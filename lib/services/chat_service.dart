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
  // A Firebase Authentication példánya a jelenlegi felhasználó UID-jének lekérdezéséhez.
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
  Future<void> sendMessage(String receiverId, String message) async {
    // Ellenőrizzük, hogy a jelenlegi felhasználó be van-e jelentkezve.
    final String? currentUserId = _auth.currentUser?.uid;
    final String? currentUserEmail = _auth.currentUser?.email;

    if (currentUserId == null || currentUserEmail == null) {
      // Ha nincs bejelentkezett felhasználó, kivételt dobunk.
      throw Exception('Nincs bejelentkezett felhasználó.');
    }

    // Létrehozzuk a chat szoba azonosítóját a küldő és fogadó UID-jei alapján.
    final String chatRoomId = getChatRoomId(currentUserId, receiverId);

    // Üzenet adatainak összeállítása Map formátumban.
    // A 'timestamp' mezőhöz `FieldValue.serverTimestamp()`-ot használunk,
    // ami biztosítja, hogy az időbélyeget a Firestore szervere állítsa be,
    // elkerülve az ügyféloldali óraeltérések okozta problémákat.
    final Map<String, dynamic> messageData = {
      'senderId': currentUserId,
      'senderEmail': currentUserEmail, // Mentjük a küldő email címét is az egyszerű megjelenítéshez
      'receiverId': receiverId,
      'message': message,
      'timestamp': FieldValue.serverTimestamp(), // Firestore szerveroldali időbélyeg
    };

    // Mentjük az üzenetet a Firestore-ba a megfelelő chat szoba alkollekciójába.
    // A struktúra: `chats` (fő kollekció) -> `[chatRoomId]` (dokumentum) -> `messages` (alkollekció) -> `[üzenet dokumentum]`
    await _firestore
        .collection('chats') // Fő chat kollekció
        .doc(chatRoomId)     // Az adott chat szoba dokumentuma (pl. "userA_userB")
        .collection('messages') // Az üzenetek alkollekciója ezen a chat szobán belül
        .add(messageData);   // Az új üzenet hozzáadása egy automatikusan generált ID-vel
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
}
