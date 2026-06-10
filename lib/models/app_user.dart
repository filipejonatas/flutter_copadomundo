class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.nick,
    required this.avatarId,
    this.photoUrl,
  });

  final String id;
  final String email;
  final String displayName;
  final String nick;
  final String avatarId;
  final String? photoUrl;

  AppUser copyWith({
    String? id,
    String? email,
    String? displayName,
    String? nick,
    String? avatarId,
    String? photoUrl,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      nick: nick ?? this.nick,
      avatarId: avatarId ?? this.avatarId,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
