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
      expect(countryCodeForTeam('Cura\u00e7ao'), 'CW');
      expect(countryCodeForTeam("C\u00f4te d'Ivoire"), 'CI');
      expect(countryCodeForTeam('Bosnia-Herzegovina'), 'BA');
      expect(countryCodeForTeam('Congo DR'), 'CD');
      expect(countryCodeForTeam('IR Iran'), 'IR');
      expect(countryCodeForTeam('Cabo Verde'), 'CV');
    });

    test(
      'maps every team returned by the published API to an existing asset',
      () {
        const teamsFromPublishedApi = <String, String>{
          'Algeria': 'DZ',
          'Argentina': 'AR',
          'Australia': 'AU',
          'Austria': 'AT',
          'Belgium': 'BE',
          'Bosnia-Herzegovina': 'BA',
          'Brazil': 'BR',
          'Cabo Verde': 'CV',
          'Canada': 'CA',
          'Colombia': 'CO',
          'Congo DR': 'CD',
          "C\u00f4te d'Ivoire": 'CI',
          'Croatia': 'HR',
          'Cura\u00e7ao': 'CW',
          'Czechia': 'CZ',
          'Ecuador': 'EC',
          'Egypt': 'EG',
          'England': 'GB-ENG',
          'France': 'FR',
          'Germany': 'DE',
          'Ghana': 'GH',
          'Haiti': 'HT',
          'IR Iran': 'IR',
          'Iraq': 'IQ',
          'Japan': 'JP',
          'Jordan': 'JO',
          'Korea Republic': 'KR',
          'Mexico': 'MX',
          'Morocco': 'MA',
          'Netherlands': 'NL',
          'New Zealand': 'NZ',
          'Norway': 'NO',
          'Panama': 'PA',
          'Paraguay': 'PY',
          'Portugal': 'PT',
          'Qatar': 'QA',
          'Saudi Arabia': 'SA',
          'Scotland': 'GB-SCT',
          'Senegal': 'SN',
          'South Africa': 'ZA',
          'Spain': 'ES',
          'Sweden': 'SE',
          'Switzerland': 'CH',
          'Tunisia': 'TN',
          'Turkey': 'TR',
          'Uruguay': 'UY',
          'USA': 'US',
          'Uzbekistan': 'UZ',
        };
        const availableFlagCodes = <String>{
          'AR',
          'AT',
          'AU',
          'BA',
          'BE',
          'BR',
          'CA',
          'CD',
          'CH',
          'CI',
          'CO',
          'CV',
          'CW',
          'CZ',
          'DE',
          'DZ',
          'EC',
          'EG',
          'ES',
          'FR',
          'GB-ENG',
          'GB-SCT',
          'GH',
          'HR',
          'HT',
          'IQ',
          'IR',
          'JO',
          'JP',
          'KR',
          'MA',
          'MX',
          'NL',
          'NO',
          'NZ',
          'PA',
          'PT',
          'PY',
          'QA',
          'SA',
          'SE',
          'SN',
          'TN',
          'TR',
          'US',
          'UY',
          'UZ',
          'ZA',
        };

        for (final entry in teamsFromPublishedApi.entries) {
          final code = countryCodeForTeam(entry.key);
          expect(code, entry.value, reason: entry.key);
          expect(availableFlagCodes, contains(code), reason: entry.key);
        }
      },
    );

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
        const penaltyMatch = MatchCard(
          match: MatchPrediction(
            fixtureId: 104,
            round: 'Round of 32',
            kickoffLabel: '29 jun, 16:00',
            kickoffAt: '2026-06-29T19:00:00Z',
            homeTeam: 'Brazil',
            awayTeam: 'France',
            status: 'FT_PEN',
            homeScore: 1,
            awayScore: 1,
            qualifiedPick: MatchPick.home,
          ),
        );

        // Act
        await tester.pumpWidget(
          buildTestApp(
            const SingleChildScrollView(
              child: Column(
                children: [
                  liveMatch,
                  scheduledMatch,
                  finishedMatch,
                  penaltyMatch,
                ],
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('Live'), findsOneWidget);
        expect(find.text('FT'), findsOneWidget);
        expect(find.text('PEN'), findsOneWidget);
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
