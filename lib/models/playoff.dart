import 'leaderboard_entry.dart';

class PlayoffBracket {
  const PlayoffBracket({
    required this.id,
    required this.maxParticipants,
    required this.generatedAt,
    required this.participants,
    required this.matches,
    this.deadlineAt,
  });

  final String id;
  final int maxParticipants;
  final String generatedAt;
  final String? deadlineAt;
  final List<PlayoffParticipant> participants;
  final List<PlayoffMatch> matches;

  factory PlayoffBracket.fromJson(Map<String, dynamic> json) {
    return PlayoffBracket(
      id: json['id'] as String,
      maxParticipants: json['maxParticipants'] as int,
      generatedAt: json['generatedAt'] as String,
      deadlineAt: json['deadlineAt'] as String?,
      participants: (json['participants'] as List<dynamic>? ?? [])
          .map(
            (item) =>
                PlayoffParticipant.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      matches: (json['matches'] as List<dynamic>? ?? [])
          .map((item) => PlayoffMatch.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PlayoffParticipant {
  const PlayoffParticipant({
    required this.userId,
    required this.seed,
    required this.nick,
    required this.avatarId,
    required this.rankingPoints,
    this.photoUrl,
  });

  final String userId;
  final int seed;
  final String nick;
  final String avatarId;
  final String? photoUrl;
  final int rankingPoints;

  factory PlayoffParticipant.fromJson(Map<String, dynamic> json) {
    return PlayoffParticipant(
      userId: json['userId'] as String,
      seed: json['seed'] as int,
      nick: json['nick'] as String,
      avatarId: json['avatarId'] as String,
      photoUrl: json['photoUrl'] as String?,
      rankingPoints: json['rankingPoints'] as int? ?? 0,
    );
  }
}

class PlayoffMatch {
  const PlayoffMatch({
    required this.id,
    required this.round,
    required this.roundIndex,
    required this.position,
    required this.status,
    required this.isBye,
    this.participantA,
    this.participantB,
    this.winnerParticipantId,
  });

  final String id;
  final String round;
  final int roundIndex;
  final int position;
  final PlayoffParticipant? participantA;
  final PlayoffParticipant? participantB;
  final String status;
  final bool isBye;
  final String? winnerParticipantId;

  factory PlayoffMatch.fromJson(Map<String, dynamic> json) {
    return PlayoffMatch(
      id: json['id'] as String,
      round: json['round'] as String,
      roundIndex: json['roundIndex'] as int,
      position: json['position'] as int,
      participantA: json['participantA'] == null
          ? null
          : PlayoffParticipant.fromJson(
              json['participantA'] as Map<String, dynamic>,
            ),
      participantB: json['participantB'] == null
          ? null
          : PlayoffParticipant.fromJson(
              json['participantB'] as Map<String, dynamic>,
            ),
      winnerParticipantId: json['winnerParticipantId'] as String?,
      status: json['status'] as String? ?? 'pending',
      isBye: json['isBye'] == true,
    );
  }
}

class PlayoffRoundScore {
  const PlayoffRoundScore({
    required this.userId,
    required this.nick,
    required this.avatarId,
    required this.points,
    required this.predictionsCount,
    required this.exactScores,
    required this.correctQualified,
    this.seed,
    this.photoUrl,
  });

  final String userId;
  final String nick;
  final String avatarId;
  final String? photoUrl;
  final int? seed;
  final int points;
  final int predictionsCount;
  final int exactScores;
  final int correctQualified;

  factory PlayoffRoundScore.fromJson(Map<String, dynamic> json) {
    return PlayoffRoundScore(
      userId: json['userId'] as String,
      nick: json['nick'] as String,
      avatarId: json['avatarId'] as String,
      photoUrl: json['photoUrl'] as String?,
      seed: json['seed'] as int?,
      points: json['points'] as int? ?? 0,
      predictionsCount: json['predictionsCount'] as int? ?? 0,
      exactScores: json['exactScores'] as int? ?? 0,
      correctQualified: json['correctQualified'] as int? ?? 0,
    );
  }
}

extension PlayoffParticipantEntry on PlayoffParticipant {
  LeaderboardEntry toLeaderboardEntry({bool isCurrentUser = false}) {
    return LeaderboardEntry(
      position: seed,
      userId: userId,
      nick: nick,
      avatarId: avatarId,
      photoUrl: photoUrl,
      points: rankingPoints,
      predictionsCount: 0,
      exactScores: 0,
      isCurrentUser: isCurrentUser,
    );
  }
}
