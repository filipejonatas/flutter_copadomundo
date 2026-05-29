enum MatchPick { home, draw, away }

class MatchPrediction {
  const MatchPrediction({
    required this.fixtureId,
    required this.round,
    required this.kickoffLabel,
    required this.homeTeam,
    required this.awayTeam,
    required this.status,
  });

  final int fixtureId;
  final String round;
  final String kickoffLabel;
  final String homeTeam;
  final String awayTeam;
  final String status;

  factory MatchPrediction.fromJson(Map<String, dynamic> json) {
    return MatchPrediction(
      fixtureId: json['fixtureId'] as int,
      round: json['round'] as String,
      kickoffLabel: json['kickoffLabel'] as String,
      homeTeam: json['homeTeam'] as String,
      awayTeam: json['awayTeam'] as String,
      status: json['status'] as String,
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
    homeTeam: 'Mexico',
    awayTeam: 'South Africa',
    status: 'NS',
  ),
  const MatchPrediction(
    fixtureId: 2026002,
    round: 'Group Stage - 1',
    kickoffLabel: '12 jun, 19:00',
    homeTeam: 'Canada',
    awayTeam: 'Japan',
    status: 'NS',
  ),
  const MatchPrediction(
    fixtureId: 2026003,
    round: 'Group Stage - 1',
    kickoffLabel: '13 jun, 13:00',
    homeTeam: 'Brazil',
    awayTeam: 'Germany',
    status: 'NS',
  ),
  const MatchPrediction(
    fixtureId: 2026004,
    round: 'Group Stage - 1',
    kickoffLabel: '14 jun, 21:00',
    homeTeam: 'Argentina',
    awayTeam: 'France',
    status: 'NS',
  ),
];
