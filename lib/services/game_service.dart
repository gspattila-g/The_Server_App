import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/game.dart';

class GameService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _userGamesCollection = 'userGames';
  static const String _gamesSubcollection = 'games';

  // UID lekérése mindig közvetlenül, nem eltárolva
  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> addGame(Game game) async {
    final uid = _currentUserId;
    if (uid == null) {
      throw Exception('Nincs bejelentkezett felhasználó. Játék hozzáadása sikertelen.');
    }
    try {
      await _firestore
          .collection(_userGamesCollection)
          .doc(uid)
          .collection(_gamesSubcollection)
          .add(game.toJson());
    } catch (e) {
      debugPrint('Hiba a játék hozzáadásakor: $e');
      rethrow;
    }
  }

  Future<void> updateGame(Game game) async {
    final uid = _currentUserId;
    if (uid == null) {
      throw Exception('Nincs bejelentkezett felhasználó. Játék frissítése sikertelen.');
    }
    try {
      await _firestore
          .collection(_userGamesCollection)
          .doc(uid)
          .collection(_gamesSubcollection)
          .doc(game.id)
          .update(game.toJson());
    } catch (e) {
      debugPrint('Hiba a játék frissítésekor: $e');
      rethrow;
    }
  }

  Future<void> deleteGame(String gameId) async {
    final uid = _currentUserId;
    if (uid == null) {
      throw Exception('Nincs bejelentkezett felhasználó. Játék törlése sikertelen.');
    }
    try {
      await _firestore
          .collection(_userGamesCollection)
          .doc(uid)
          .collection(_gamesSubcollection)
          .doc(gameId)
          .delete();
    } catch (e) {
      debugPrint('Hiba a játék törlésekor: $e');
      rethrow;
    }
  }

  Stream<List<Game>> getGamesStream() {
    final uid = _currentUserId;
    if (uid == null) {
      return Stream.value([]);
    }
    return _firestore
        .collection(_userGamesCollection)
        .doc(uid)
        .collection(_gamesSubcollection)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Game.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Game>> getGamesStreamForUser(String userId) {
    return _firestore
        .collection(_userGamesCollection)
        .doc(userId)
        .collection(_gamesSubcollection)
        .orderBy('addedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Game.fromFirestore(doc)).toList();
    });
  }

  Future<Game?> getGameById(String gameId) async {
    final uid = _currentUserId;
    if (uid == null) {
      throw Exception('Nincs bejelentkezett felhasználó. Játék lekérése sikertelen.');
    }
    try {
      final docSnapshot = await _firestore
          .collection(_userGamesCollection)
          .doc(uid)
          .collection(_gamesSubcollection)
          .doc(gameId)
          .get();
      if (docSnapshot.exists) {
        return Game.fromFirestore(docSnapshot);
      }
      return null;
    } catch (e) {
      debugPrint('Hiba a játék lekérésekor ID alapján: $e');
      rethrow;
    }
  }
}