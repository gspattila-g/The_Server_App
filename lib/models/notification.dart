import 'package:cloud_firestore/cloud_firestore.dart';

/// AppNotification modell osztály
///
/// Egy alkalmazáson belüli értesítést reprezentál.
class AppNotification {
  String? id; // Az értesítés Firestore dokumentum ID-je (opcionális, mert hozzáadáskor generálódik)
  final String senderId; // A küldő felhasználó UID-je
  final String receiverId; // A fogadó felhasználó UID-je
  final String type; // Az értesítés típusa (pl. 'friend_request', 'friend_request_accepted')
  final String message; // Az értesítés üzenete
  final String? eventId; // Az esemény ID-je, amire az értesítés vonatkozik (pl. barátsági kérés ID-je)
  final Timestamp timestamp; // Az értesítés időbélyege
  bool isRead; // Olvasott-e az értesítés

  AppNotification({
    this.id,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.message,
    this.eventId,
    required this.timestamp,
    this.isRead = false, // Alapértelmezésben olvasatlan
  });

  /// Adatok átalakítása Firestore-ba menthető Map formátummá.
  ///
  /// Ez a metódus biztosítja, hogy az AppNotification objektum adatai
  /// helyes formában kerüljenek a Firestore-ba.
  Map<String, dynamic> toJson() { // <<< MÓDOSÍTVA: toMap() helyett toJson()
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'type': type,
      'message': message,
      'eventId': eventId,
      'timestamp': timestamp,
      'isRead': isRead,
    };
  }

  /// Adatok betöltése Firestore-ból érkező Map-ből AppNotification objektummá.
  ///
  /// [data] a Firestore dokumentumból származó Map<String, dynamic> adatok.
  /// [id] az értesítés Firestore dokumentum ID-je.
  ///
  /// Ez a factory konstruktor azért felelős, hogy egy Firestore snapshotból
  /// létrehozza az AppNotification objektumot, beleértve a dokumentum ID-jét is.
  factory AppNotification.fromFirestore(Map<String, dynamic> data, String id) {
    return AppNotification(
      id: id, // Itt tároljuk el a dokumentum ID-jét
      senderId: data['senderId'] as String,
      receiverId: data['receiverId'] as String,
      type: data['type'] as String,
      message: data['message'] as String,
      eventId: data['eventId'] as String?, // Opcionális mező
      timestamp: data['timestamp'] as Timestamp,
      isRead: data['isRead'] as bool? ?? false, // Alapértelmezés false, ha hiányzik
    );
  }
}
