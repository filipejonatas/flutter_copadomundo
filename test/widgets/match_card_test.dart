import 'package:copa_palpite/models/match_prediction.dart';
import 'package:copa_palpite/widgets/match_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('countryCodeForTeam', () {
    test('maps current API team names to their own flags', () {
      expect(countryCodeForTeam('England'), 'GB-ENG');
      expect(countryCodeForTeam('Scotland'), 'GB-SCT');
      expect(countryCodeForTeam('Curaçao'), 'CW');
      expect(countryCodeForTeam("Côte d'Ivoire"), 'CI');
      expect(countryCodeForTeam('Bosnia-Herzegovina'), 'BA');
      expect(countryCodeForTeam('Congo DR'), 'CD');
      expect(countryCodeForTeam('IR Iran'), 'IR');
      expect(countryCodeForTeam('Cabo Verde'), 'CV');
    });

    test('does not fall back to USA for unknown teams', () {
      expect(countryCodeForTeam('Winner Group A'), isNull);
      expect(countryCodeForTeam(''), isNull);
    });
  });

  group('MatchCard', () {
    testWidgets('should render home and away team flags correctly', (
      tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        buildTestApp(const MatchCard(match: futureMatch)),
      );

      // Act
      await tester.pump();

      // Assert
      expect(find.byType(TeamFlag), findsNWidgets(2));
      expect(find.text('Brazil'), findsOneWidget);
      expect(find.text('Germany'), findsOneWidget);
    });

    testWidgets('should render score correctly', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildTestApp(const MatchCard(match: lockedMatch)),
      );

      // Act
      await tester.pump();

      // Assert
      expect(find.text('2 - 1'), findsOneWidget);
    });

    testWidgets(
      'should display correct status labels for live, finished, and scheduled',
      (tester) async {
        // Arrange
        const liveMatch = MatchCard(
          match: MatchPrediction(
            fixtureId: 103,
            round: 'Group Stage - 1',
            kickoffLabel: '11 jun, 16:00',
            kickoffAt: '2099-06-11T19:00:00Z',
            homeTeam: 'Argentina',
            awayTeam: 'France',
            status: 'LIVE',
            homeScore: 1,
            awayScore: 0,
          ),
        );
        const scheduledMatch = MatchCard(match: futureMatch);
        const finishedMatch = MatchCard(match: lockedMatch);

        // Act
        await tester.pumpWidget(
          buildTestApp(
            const SingleChildScrollView(
              child: Column(
                children: [liveMatch, scheduledMatch, finishedMatch],
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('Live'), findsOneWidget);
        expect(find.text('FT'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
      },
    );

    testWidgets('should trigger onTap callback when tapped', (tester) async {
      // Arrange
      var tapped = false;
      await tester.pumpWidget(
        buildTestApp(MatchCard(match: futureMatch, onTap: () => tapped = true)),
      );

      // Act
      await tester.tap(find.byType(MatchCard));
      await tester.pump();

      // Assert
      expect(tapped, isTrue);
    });
  });
}
