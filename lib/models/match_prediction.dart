enum MatchPick { home, draw, away }

class UserMatchPrediction {
  const UserMatchPrediction({
    required this.pick,
    this.homeScore,
    this.awayScore,
  });

  final MatchPick pick;
  final int? homeScore;
  final int? awayScore;

  bool get hasExactScore => homeScore != null && awayScore != null;
}

class MatchPrediction {
  const MatchPrediction({
    required this.fixtureId,
    required this.round,
    required this.kickoffLabel,
    required this.kickoffAt,
    required this.homeTeam,
    required this.awayTeam,
    required this.status,
    this.homeScore,
    this.awayScore,
  });

  final int fixtureId;
  final String round;
  final String kickoffLabel;
  final String kickoffAt;
  final String homeTeam;
  final String awayTeam;
  final String status;
  final int? homeScore;
  final int? awayScore;

  bool get hasResult => homeScore != null && awayScore != null;

  bool get hasValidKickoff => DateTime.tryParse(kickoffAt) != null;

  bool isPredictionOpen({DateTime? now}) {
    final kickoff = DateTime.tryParse(kickoffAt);
    if (kickoff == null) return false;
    if (!_isPreMatchStatus(status)) return false;

    final referenceTime = now ?? DateTime.now().toUtc();
    return referenceTime.isBefore(kickoff.toUtc());
  }

  factory MatchPrediction.fromJson(Map<String, dynamic> json) {
    return MatchPrediction(
      fixtureId: json['fixtureId'] as int,
      round: json['round'] as String,
      kickoffLabel: json['kickoffLabel'] as String,
      kickoffAt: json['kickoffAt'] as String? ?? '',
      homeTeam: json['homeTeam'] as String,
      awayTeam: json['awayTeam'] as String,
      status: json['status'] as String,
      homeScore: intFromStorageValue(json['homeScore']),
      awayScore: intFromStorageValue(json['awayScore']),
    );
  }
}

bool _isPreMatchStatus(String status) {
  return switch (status.trim().toUpperCase()) {
    'NS' || 'TBD' || 'SCHEDULED' || 'NOT_STARTED' || 'PRE_MATCH' => true,
    _ => false,
  };
}

bool isValidPredictionScore(int? score) {
  return score != null && score >= 0 && score <= 9;
}

String pickToStorageValue(MatchPick pick) {
  return switch (pick) {
    MatchPick.home => 'home',
    MatchPick.draw => 'draw',
    MatchPick.away => 'away',
  };
}

MatchPick? pickFromStorageValue(Object? value) {
  return switch (value) {
    'home' => MatchPick.home,
    'draw' => MatchPick.draw,
    'away' => MatchPick.away,
    _ => null,
  };
}

UserMatchPrediction? userMatchPredictionFromMap(Map<String, dynamic> value) {
  final pick = pickFromStorageValue(value['pick']);
  if (pick == null) return null;

  return UserMatchPrediction(
    pick: pick,
    homeScore: intFromStorageValue(value['homeScore']),
    awayScore: intFromStorageValue(value['awayScore']),
  );
}

int? intFromStorageValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

MatchPick pickFromScore(int homeScore, int awayScore) {
  if (homeScore == awayScore) return MatchPick.draw;
  return homeScore > awayScore ? MatchPick.home : MatchPick.away;
}

final mockMatches = <MatchPrediction>[
  const MatchPrediction(
    fixtureId: 2026001,
    round: 'Group Stage - 1',
    kickoffLabel: '11 jun, 16:00',
    kickoffAt: '2026-06-11T19:00:00Z',
    homeTeam: 'Mexico',
    awayTeam: 'South Africa',
    status: 'FT',
    homeScore: 2,
    awayScore: 1,
  ),
  const MatchPrediction(
    fixtureId: 2026002,
    round: 'Group Stage - 1',
    kickoffLabel: '12 jun, 19:00',
    kickoffAt: '2026-06-12T22:00:00Z',
    homeTeam: 'Canada',
    awayTeam: 'Japan',
    status: 'FT',
    homeScore: 1,
    awayScore: 1,
  ),
  const MatchPrediction(
    fixtureId: 2026003,
    round: 'Group Stage - 1',
    kickoffLabel: '13 jun, 13:00',
    kickoffAt: '2026-06-13T16:00:00Z',
    homeTeam: 'Brazil',
    awayTeam: 'Germany',
    status: 'NS',
  ),
  const MatchPrediction(
    fixtureId: 2026004,
    round: 'Group Stage - 1',
    kickoffLabel: '14 jun, 21:00',
    kickoffAt: '2026-06-15T00:00:00Z',
    homeTeam: 'Argentina',
    awayTeam: 'France',
    status: 'NS',
  ),
];
