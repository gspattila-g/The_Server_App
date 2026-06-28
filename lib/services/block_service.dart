import 'package:cloud_firestore/cloud_firestore.dart';

class BlockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // A blocks/{userId} dokumentum struktúra:
  // { blockedIds: [...], blockedByIds: [...] }
  // blockedIds   = akiket én blokkoltam
  // blockedByIds = akik engem blokkoltam

  Future<void> blockUser(String currentUserId, String targetId) async {
    final batch = _firestore.batch();

    batch.set(
      _firestore.collection('blocks').doc(currentUserId),
      {'blockedIds': FieldValue.arrayUnion([targetId])},
      SetOptions(merge: true),
    );
    batch.set(
      _firestore.collection('blocks').doc(targetId),
      {'blockedByIds': FieldValue.arrayUnion([currentUserId])},
      SetOptions(merge: true),
    );

    // Barátság eltávolítása mindkét irányban
    batch.set(
      _firestore.collection('friends').doc(currentUserId),
      {'friendIds': FieldValue.arrayRemove([targetId])},
      SetOptions(merge: true),
    );
    batch.set(
      _firestore.collection('friends').doc(targetId),
      {'friendIds': FieldValue.arrayRemove([currentUserId])},
      SetOptions(merge: true),
    );

    await batch.commit();

    // Barátsági kérések törlése
    final requests = await _firestore
        .collection('friendRequests')
        .where('senderId', whereIn: [currentUserId, targetId])
        .where('receiverId', whereIn: [currentUserId, targetId])
        .get();
    for (final doc in requests.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> unblockUser(String currentUserId, String targetId) async {
    final batch = _firestore.batch();
    batch.update(
      _firestore.collection('blocks').doc(currentUserId),
      {'blockedIds': FieldValue.arrayRemove([targetId])},
    );
    batch.update(
      _firestore.collection('blocks').doc(targetId),
      {'blockedByIds': FieldValue.arrayRemove([currentUserId])},
    );
    await batch.commit();
  }

  // Stream a saját blokk dokumentumhoz — tartalmazza ki blokkoltam és ki blokkolt engem
  Stream<DocumentSnapshot> getMyBlockDocStream(String userId) {
    return _firestore.collection('blocks').doc(userId).snapshots();
  }

  // Visszaadja az összes rejtendő UID-t (akiket blokkoltam + akik blokkolt engem)
  Stream<Set<String>> getHiddenUserIdsStream(String userId) {
    return getMyBlockDocStream(userId).map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      final blocked = List<String>.from(data?['blockedIds'] ?? []);
      final blockedBy = List<String>.from(data?['blockedByIds'] ?? []);
      return {...blocked, ...blockedBy};
    });
  }

  // Blokkolt felhasználók listája (akiket én blokkoltam)
  Stream<List<String>> getBlockedIdsStream(String userId) {
    return getMyBlockDocStream(userId).map((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      return List<String>.from(data?['blockedIds'] ?? []);
    });
  }
}
