import 'package:cloud_firestore/cloud_firestore.dart';

/// A játék adatait reprezentáló modell osztály.
///
/// Tartalmazza a játék nevét, műfaját, platformját,
/// és a játék állapotát a felhasználó könyvtárában (pl. kívánságlista, játszott).
class Game {
  final String id; // A játék dokumentum ID-je a Firestore-ban
  final String name; // A játék neve
  final String genre; // Műfaj (pl. RPG, FPS, Stratégia)
  final String platform; // Platform (pl. PC, PlayStation, Xbox, Switch)
  String status; // Állapot (pl. 'wishlist', 'playing', 'completed', 'dropped')
  final Timestamp addedAt; // Hozzáadás időpontja
  int? rating; // Értékelés (1-5), null = nincs értékelve

  Game({
    required this.id,
    required this.name,
    this.genre = 'Ismeretlen', // Alapértelmezett érték
    this.platform = 'Ismeretlen', // Alapértelmezett érték
    this.status = 'wishlist', // Alapértelmezett állapot
    required this.addedAt,
    this.rating,
  });

  /// Adatok átalakítása Firestore-ba menthető Map formátummá.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'genre': genre,
      'platform': platform,
      'status': status,
      'addedAt': addedAt,
      'rating': rating,
    };
  }

  /// Adatok betöltése Firestore DocumentSnapshot-ból Game objektummá.
  factory Game.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Game(
      id: doc.id, // A dokumentum ID-je
      name: data['name'] ?? 'Ismeretlen játék',
      genre: data['genre'] ?? 'Ismeretlen',
      platform: data['platform'] ?? 'Ismeretlen',
      status: data['status'] ?? 'wishlist',
      addedAt: data['addedAt'] as Timestamp? ?? Timestamp.now(),
      rating: data['rating'] as int?,
    );
  }
}
