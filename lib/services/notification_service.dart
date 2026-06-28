import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification.dart';

/// Értesítési szolgáltatás osztály
///
/// Ez az osztály felelős az értesítések Firestore adatbázisban történő kezeléséért.
/// Lehetővé teszi új értesítések hozzáadását, felhasználóhoz tartozó értesítések lekérdezését,
/// és értesítések olvasottként való megjelölését.
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Értesítések kollekcióra mutató referencia.
  ///
  /// Az értesítések itt tárolódnak a Firestore-ban.
  CollectionReference get _notificationsCollection =>
      _firestore.collection('notifications');

  /// Új értesítés hozzáadása a Firestore-hoz.
  ///
  /// [notification]: Az `AppNotification` objektum, amit hozzá szeretnénk adni.
  ///
  /// Visszatérési érték: A hozzáadott értesítés ID-je (String).
  Future<String> addNotification(AppNotification notification) async {
    try {
      final docRef = await _notificationsCollection.add(notification.toJson());
      // Visszaadjuk a Firestore által generált dokumentum ID-t.
      return docRef.id;
    } catch (e) {
      debugPrint('Hiba az értesítés hozzáadásakor: $e');
      rethrow; // Újra dobjuk a kivételt, hogy a hívó kezelhesse.
    }
  }

  /// Értesítések lekérdezése egy adott felhasználó számára valós időben.
  ///
  /// [receiverId]: Annak a felhasználónak az UID-je, akinek az értesítéseit lekérdezzük.
  ///
  /// Visszatérési érték: Egy `Stream<List<AppNotification>>`, amely valós időben
  /// frissül, amikor változás történik a felhasználó értesítéseiben.
  Stream<List<AppNotification>> getNotificationsForUser(String receiverId) {
    return _notificationsCollection
        .where('receiverId', isEqualTo: receiverId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
          .where((n) => n.type != 'message')
          .toList();
    });
  }

  /// Egy értesítés olvasottként való megjelölése.
  ///
  /// [notificationId]: Annak az értesítésnek az ID-je, amelyet olvasottként szeretnénk megjelölni.
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).update({'isRead': true});
    } catch (e) {
      debugPrint('Hiba az értesítés olvasottként jelölésekor: $e');
      rethrow;
    }
  }

  /// Összes értesítés olvasottként való megjelölése egy adott felhasználó számára.
  ///
  /// [receiverId]: Annak a felhasználónak az UID-je, akinek az összes értesítését olvasottként szeretnénk megjelölni.
  Future<void> markAllNotificationsAsRead(String receiverId) async {
    try {
      final querySnapshot = await _notificationsCollection
          .where('receiverId', isEqualTo: receiverId)
          .where('isRead', isEqualTo: false) // Csak az olvasatlanokat frissítjük
          .get();

      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Hiba az összes értesítés olvasottként jelölésekor: $e');
      rethrow;
    }
  }

  Stream<int> getUnreadCountStream(String receiverId) {
    return _notificationsCollection
        .where('receiverId', isEqualTo: receiverId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs
            .where((doc) => (doc.data() as Map<String, dynamic>)['type'] != 'message')
            .length);
  }

  /// Értesítés törlése az adatbázisból.
  ///
  /// [notificationId]: Az értesítés ID-je, amit törölni szeretnénk.
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _notificationsCollection.doc(notificationId).delete();
    } catch (e) {
      debugPrint('Hiba az értesítés törlésekor: $e');
      rethrow;
    }
  }
}
