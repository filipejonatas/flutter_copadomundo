import 'package:copa_palpite/models/match_prediction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchPrediction.isPredictionOpen', () {
    test('allows predictions before kickoff for pre-match statuses', () {
      const match = MatchPrediction(
        fixtureId: 1,
        round: 'Group Stage',
        kickoffLabel: '11 jun, 16:00',
        kickoffAt: '2026-06-11T19:00:00Z',
        homeTeam: 'Mexico',
        awayTeam: 'South Africa',
        status: 'NS',
      );

      expect(
        match.isPredictionOpen(now: DateTime.parse('2026-06-11T18:59:59Z')),
        isTrue,
      );
    });

    test('blocks predictions at kickoff', () {
      const match = MatchPrediction(
        fixtureId: 1,
        round: 'Group Stage',
        kickoffLabel: '11 jun, 16:00',
        kickoffAt: '2026-06-11T19:00:00Z',
        homeTeam: 'Mexico',
        awayTeam: 'South Africa',
        status: 'NS',
      );

      expect(
        match.isPredictionOpen(now: DateTime.parse('2026-06-11T19:00:00Z')),
        isFalse,
      );
    });

    test('blocks predictions for finished matches', () {
      const match = MatchPrediction(
        fixtureId: 1,
        round: 'Group Stage',
        kickoffLabel: '11 jun, 16:00',
        kickoffAt: '2026-06-11T19:00:00Z',
        homeTeam: 'Mexico',
        awayTeam: 'South Africa',
        status: 'FT',
        homeScore: 2,
        awayScore: 1,
      );

      expect(
        match.isPredictionOpen(now: DateTime.parse('2026-06-11T18:00:00Z')),
        isFalse,
      );
    });
  });

  group('isValidPredictionScore', () {
    test('accepts scores from 0 to 9', () {
      expect(isValidPredictionScore(0), isTrue);
      expect(isValidPredictionScore(9), isTrue);
    });

    test('rejects null, negative, and high scores', () {
      expect(isValidPredictionScore(null), isFalse);
      expect(isValidPredictionScore(-1), isFalse);
      expect(isValidPredictionScore(10), isFalse);
    });
  });
}
