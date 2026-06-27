import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import '../models/user_profile.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const String _collectionName = 'userProfiles';

  Future<String> uploadProfileImage(String uid, File imageFile) async {
    try {
      final ref = _storage.ref().child('profile_images').child('$uid.jpg');
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      await ref.putFile(imageFile, metadata);
      final downloadUrl = await ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Hiba a profilkép feltöltésekor: $e');
      rethrow;
    }
  }

  Future<void> deleteProfileImage(String uid) async {
    try {
      final ref = _storage.ref().child('profile_images').child('$uid.jpg');
      await ref.delete();
    } catch (e) {
      debugPrint('Profilkép törlése: $e');
    }
  }

  Future<void> createProfile(UserProfile userProfile) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(userProfile.uid)
          .set(userProfile.toJson());
    } catch (e) {
      debugPrint('Hiba a profil létrehozásakor: $e');
      rethrow;
    }
  }

  Future<UserProfile?> getProfile(String uid) async {
    try {
      final doc = await _firestore.collection(_collectionName).doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserProfile.fromFirestore(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Hiba a profil lekérésekor: $e');
      rethrow;
    }
  }

  Future<void> updateProfile(UserProfile userProfile) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(userProfile.uid)
          .set(userProfile.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Hiba a profil frissítésekor: $e');
      rethrow;
    }
  }

  Future<void> deleteProfile(String uid) async {
    try {
      await deleteProfileImage(uid);
      await _firestore.collection(_collectionName).doc(uid).delete();
    } catch (e) {
      debugPrint('Hiba a profil törlésekor: $e');
      rethrow;
    }
  }

  Future<void> setStatus(String uid, String status) async {
    await _firestore.collection(_collectionName).doc(uid).set({'status': status}, SetOptions(merge: true));
  }

  Stream<UserProfile?> getProfileStream(String uid) {
    return _firestore.collection(_collectionName).doc(uid).snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        return UserProfile.fromFirestore(snapshot.data() as Map<String, dynamic>);
      }
      return null;
    });
  }
}