class UserProfile {
  final String uid;
  final String email;
  String displayName;
  String bio;
  String favoriteGame;
  String? profileImageUrl;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName = 'Új felhasználó',
    this.bio = 'Nincs bemutatkozás',
    this.favoriteGame = 'Nincs kedvenc játék',
    this.profileImageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'bio': bio,
      'favoriteGame': favoriteGame,
      'profileImageUrl': profileImageUrl,
    };
  }

  factory UserProfile.fromFirestore(Map<String, dynamic> data) {
    return UserProfile(
      uid: data['uid'] as String,
      email: data['email'] as String,
      displayName: data['displayName'] as String? ?? 'Új felhasználó',
      bio: data['bio'] as String? ?? 'Nincs bemutatkozás',
      favoriteGame: data['favoriteGame'] as String? ?? 'Nincs kedvenc játék',
      profileImageUrl: data['profileImageUrl'] as String? ??
          ((data['profileImagePath'] as String?)?.startsWith('http') == true
              ? data['profileImagePath'] as String?
              : null),
    );
  }

  factory UserProfile.fromMap(String uid, String email, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: map['displayName'] ?? 'Új felhasználó',
      bio: map['bio'] ?? 'Nincs bemutatkozás',
      favoriteGame: map['favoriteGame'] ?? 'Nincs kedvenc játék',
      profileImageUrl: map['profileImageUrl'] as String?,
    );
  }

  UserProfile copyWith({
    String? displayName,
    String? bio,
    String? favoriteGame,
    String? profileImageUrl,
  }) {
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      favoriteGame: favoriteGame ?? this.favoriteGame,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}