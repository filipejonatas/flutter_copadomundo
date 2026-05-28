class LeaderboardEntry {
  const LeaderboardEntry({
    required this.position,
    required this.nick,
    required this.avatarId,
    required this.points,
    required this.exactScores,
    this.isCurrentUser = false,
  });

  final int position;
  final String nick;
  final String avatarId;
  final int points;
  final int exactScores;
  final bool isCurrentUser;
}
