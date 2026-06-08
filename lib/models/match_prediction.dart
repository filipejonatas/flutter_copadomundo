enum MatchPick { home, draw, away }

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

  factory MatchPrediction.fromJson(Map<String, dynamic> json) {
    return MatchPrediction(
      fixtureId: json['fixtureId'] as int,
      round: json['round'] as String,
      kickoffLabel: json['kickoffLabel'] as String,
      kickoffAt: json['kickoffAt'] as String? ?? '',
      homeTeam: json['homeTeam'] as String,
      awayTeam: json['awayTeam'] as String,
      status: json['status'] as String,
      homeScore: json['homeScore'] as int?,
      awayScore: json['awayScore'] as int?,
    );
  }
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
