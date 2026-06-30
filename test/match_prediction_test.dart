import 'package:copa_palpite/models/match_prediction.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MatchPrediction.isPredictionOpen', () {
    test('allows predictions before kickoff for pre-match statuses', () {
      for (final status in ['NS', 'PRE', 'TBD', 'SCHEDULED', 'NOT_STARTED']) {
        // Arrange
        final match = MatchPrediction(
          fixtureId: 1,
          round: 'Group Stage',
          kickoffLabel: '11 jun, 16:00',
          kickoffAt: '2026-06-11T19:00:00Z',
          homeTeam: 'Mexico',
          awayTeam: 'South Africa',
          status: status,
        );

        // Act
        final isOpen = match.isPredictionOpen(
          now: DateTime.parse('2026-06-11T18:59:59Z'),
        );

        // Assert
        expect(isOpen, isTrue, reason: 'status $status should be open');
      }
    });

    test('blocks predictions at kickoff', () {
      // Arrange
      const match = MatchPrediction(
        fixtureId: 1,
        round: 'Group Stage',
        kickoffLabel: '11 jun, 16:00',
        kickoffAt: '2026-06-11T19:00:00Z',
        homeTeam: 'Mexico',
        awayTeam: 'South Africa',
        status: 'NS',
      );

      // Act
      final isOpen = match.isPredictionOpen(
        now: DateTime.parse('2026-06-11T19:00:00Z'),
      );

      // Assert
      expect(isOpen, isFalse);
    });

    test('blocks predictions for finished matches', () {
      // Arrange
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

      // Act
      final isOpen = match.isPredictionOpen(
        now: DateTime.parse('2026-06-11T18:00:00Z'),
      );

      // Assert
      expect(isOpen, isFalse);
    });
  });

  group('MatchPrediction.isFinished', () {
    test('treats FT_PEN as a finished match', () {
      const match = MatchPrediction(
        fixtureId: 1,
        round: 'Round of 32',
        kickoffLabel: '29 jun, 16:00',
        kickoffAt: '2026-06-29T19:00:00Z',
        homeTeam: 'Brazil',
        awayTeam: 'France',
        status: 'FT_PEN',
        homeScore: 1,
        awayScore: 1,
        qualifiedPick: MatchPick.home,
      );

      expect(match.isFinished, isTrue);
      expect(match.isPredictionOpen(), isFalse);
    });
  });

  group('MatchPrediction.fromJson', () {
    test('parses penalty score and qualified pick', () {
      final match = MatchPrediction.fromJson({
        'fixtureId': 101,
        'round': 'R32',
        'kickoffLabel': '29 jun, 22:00',
        'kickoffAt': '2026-06-30T01:00:00Z',
        'homeTeam': 'Netherlands',
        'awayTeam': 'Morocco',
        'status': 'FT_PEN',
        'homeScore': 1,
        'awayScore': 1,
        'homePenaltyScore': 2,
        'awayPenaltyScore': 3,
        'qualifiedPick': 'away',
      });

      expect(match.homePenaltyScore, 2);
      expect(match.awayPenaltyScore, 3);
      expect(match.qualifiedPick, MatchPick.away);
      expect(match.isFinished, isTrue);
    });
  });

  group('isValidPredictionScore', () {
    test('accepts scores from 0 to 9', () {
      // Arrange
      const minScore = 0;
      const maxScore = 9;

      // Act
      final acceptsMin = isValidPredictionScore(minScore);
      final acceptsMax = isValidPredictionScore(maxScore);

      // Assert
      expect(acceptsMin, isTrue);
      expect(acceptsMax, isTrue);
    });

    test('rejects null, negative, and high scores', () {
      // Arrange
      const negativeScore = -1;
      const highScore = 10;

      // Act
      final acceptsNull = isValidPredictionScore(null);
      final acceptsNegative = isValidPredictionScore(negativeScore);
      final acceptsHigh = isValidPredictionScore(highScore);

      // Assert
      expect(acceptsNull, isFalse);
      expect(acceptsNegative, isFalse);
      expect(acceptsHigh, isFalse);
    });
  });
}
