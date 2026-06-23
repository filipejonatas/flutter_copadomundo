import 'package:copa_palpite/models/match_prediction.dart';
import 'package:copa_palpite/utils/match_day_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('initialMatchDayIndex', () {
    test('selects the day that matches today', () {
      final days = [
        [_match(1, '2026-06-22T19:00:00Z')],
        [_match(2, '2026-06-23T19:00:00Z')],
        [_match(3, '2026-06-24T19:00:00Z')],
      ];

      expect(
        initialMatchDayIndex(days, now: DateTime.parse('2026-06-23T12:00:00Z')),
        1,
      );
    });

    test('selects the next future day when today has no matches', () {
      final days = [
        [_match(1, '2026-06-22T19:00:00Z')],
        [_match(2, '2026-06-24T19:00:00Z')],
      ];

      expect(
        initialMatchDayIndex(days, now: DateTime.parse('2026-06-23T12:00:00Z')),
        1,
      );
    });

    test('selects the last valid day after all matches ended', () {
      final days = [
        [_match(1, '2026-06-22T19:00:00Z')],
        [_match(2, '2026-06-24T19:00:00Z')],
      ];

      expect(
        initialMatchDayIndex(days, now: DateTime.parse('2026-06-25T12:00:00Z')),
        1,
      );
    });
  });
}

MatchPrediction _match(int fixtureId, String kickoffAt) {
  return MatchPrediction(
    fixtureId: fixtureId,
    round: 'Group',
    kickoffLabel: '23 jun, 16:00',
    kickoffAt: kickoffAt,
    homeTeam: 'Brazil',
    awayTeam: 'Japan',
    status: 'NS',
  );
}
