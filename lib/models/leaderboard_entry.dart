class LeaderboardEntry {
  const LeaderboardEntry({
    required this.position,
    required this.userId,
    required this.nick,
    required this.avatarId,
    required this.points,
    required this.predictionsCount,
    required this.exactScores,
    this.photoUrl,
    this.isCurrentUser = false,
  });

  final int position;
  final String userId;
  final String nick;
  final String avatarId;
  final String? photoUrl;
  final int points;
  final int predictionsCount;
  final int exactScores;
  final bool isCurrentUser;

  LeaderboardEntry copyWith({
    int? position,
    String? userId,
    String? nick,
    String? avatarId,
    String? photoUrl,
    int? points,
    int? predictionsCount,
    int? exactScores,
    bool? isCurrentUser,
  }) {
    return LeaderboardEntry(
      position: position ?? this.position,
      userId: userId ?? this.userId,
      nick: nick ?? this.nick,
      avatarId: avatarId ?? this.avatarId,
      photoUrl: photoUrl ?? this.photoUrl,
      points: points ?? this.points,
      predictionsCount: predictionsCount ?? this.predictionsCount,
      exactScores: exactScores ?? this.exactScores,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }
}
