import 'package:copa_palpite/screens/leaderboard_screen.dart';
import 'package:copa_palpite/screens/login_screen.dart';
import 'package:copa_palpite/screens/splash_page.dart';
import 'package:copa_palpite/models/match_prediction.dart';
import 'package:copa_palpite/theme/app_theme.dart';
import 'package:copa_palpite/widgets/match_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_helpers.dart';

const _runGoldens = bool.fromEnvironment('RUN_GOLDENS');

void main() {
  group('Golden tests', () {
    testGoldens('SplashPage matches iPhone 14 screenshot', (tester) async {
      // Arrange
      await tester.pumpWidgetBuilder(
        const SplashPage(),
        wrapper: materialAppWrapper(theme: AppTheme.dark()),
        surfaceSize: const Size(390, 844),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      await screenMatchesGolden(tester, 'splash_page_iphone_14');
    }, skip: !_runGoldens);

    testGoldens('LoginPage matches screenshot', (tester) async {
      // Arrange
      await tester.pumpWidgetBuilder(
        LoginPage(sessionController: TestSessionController(currentUser: null)),
        wrapper: materialAppWrapper(theme: AppTheme.dark()),
        surfaceSize: const Size(390, 844),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      await screenMatchesGolden(tester, 'login_page');
    }, skip: !_runGoldens);

    testGoldens('MatchCard states match screenshots', (tester) async {
      // Arrange
      await tester.pumpWidgetBuilder(
        const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MatchCard(match: futureMatch),
            SizedBox(height: 12),
            MatchCard(match: lockedMatch),
            SizedBox(height: 12),
            MatchCard(
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
            ),
          ],
        ),
        wrapper: materialAppWrapper(theme: AppTheme.dark()),
        surfaceSize: const Size(390, 520),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      await screenMatchesGolden(tester, 'match_card_states');
    }, skip: !_runGoldens);

    testGoldens('RankingPage top 3 matches screenshot', (tester) async {
      // Arrange
      final service = MockLeaderboardService();
      when(
        () => service.loadLeaderboard(testUser),
      ).thenAnswer((_) async => leaderboardEntries());
      await tester.pumpWidgetBuilder(
        LeaderboardScreen(
          sessionController: TestSessionController(),
          leaderboardService: service,
        ),
        wrapper: materialAppWrapper(theme: AppTheme.dark()),
        surfaceSize: const Size(390, 844),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      await screenMatchesGolden(tester, 'ranking_page_top_3');
    }, skip: !_runGoldens);
  });
}
