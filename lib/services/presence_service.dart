import 'package:firebase_database/firebase_database.dart';

class PresenceService {
  static final _db = FirebaseDatabase.instance;

  static Stream<bool> get connected {
    return _db
        .ref('.info/connected')
        .onValue
        .map((event) => (event.snapshot.value as bool?) ?? false);
  }

  static void initialize(String uid) {
    final ref = _db.ref('status/$uid');
    ref.onDisconnect().set({'state': 'offline'});
    ref.set({'state': 'online'});
  }

  static void setStatus(String uid, String status) {
    _db.ref('status/$uid').set({'state': status});
  }

  static void setOffline(String uid) {
    final ref = _db.ref('status/$uid');
    ref.onDisconnect().cancel();
    ref.set({'state': 'offline'});
  }

  static Stream<String> statusStream(String uid) {
    return _db
        .ref('status/$uid/state')
        .onValue
        .map((event) => (event.snapshot.value as String?) ?? 'offline');
  }
}
