import 'package:copa_palpite/screens/leaderboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('LeaderboardScreen', () {
    late MockLeaderboardService leaderboardService;
    late TestSessionController sessionController;

    setUp(() {
      leaderboardService = MockLeaderboardService();
      sessionController = TestSessionController();
    });

    testWidgets('should render list of RankingCard widgets', (tester) async {
      // Arrange
      when(
        () => leaderboardService.loadLeaderboard(testUser),
      ).thenAnswer((_) async => leaderboardEntries());

      // Act
      await tester.pumpWidget(
        _buildScreen(sessionController, leaderboardService),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(LeaderboardTile), findsNWidgets(3));
      expect(find.text('Canarinho'), findsOneWidget);
      expect(find.text('User Test'), findsOneWidget);
    });

    testWidgets('should highlight top 3 positions with trophy icon', (
      tester,
    ) async {
      // Arrange
      when(
        () => leaderboardService.loadLeaderboard(testUser),
      ).thenAnswer((_) async => leaderboardEntries());

      // Act
      await tester.pumpWidget(
        _buildScreen(sessionController, leaderboardService),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byTooltip('Top 3'), findsNWidgets(3));
    });

    testWidgets('should show empty state when ranking list is empty', (
      tester,
    ) async {
      // Arrange
      when(
        () => leaderboardService.loadLeaderboard(testUser),
      ).thenAnswer((_) async => []);

      // Act
      await tester.pumpWidget(
        _buildScreen(sessionController, leaderboardService),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Nenhum palpite registrado ainda.'), findsOneWidget);
    });
  });
}

Widget _buildScreen(
  TestSessionController sessionController,
  MockLeaderboardService leaderboardService,
) {
  return buildTestApp(
    LeaderboardScreen(
      sessionController: sessionController,
      leaderboardService: leaderboardService,
    ),
  );
}
