import 'package:copa_palpite/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('BottomNavigationBar', () {
    testWidgets('should navigate to correct screen on each tab tap', (
      tester,
    ) async {
      // Arrange
      final sessionController = TestSessionController();
      await tester.pumpWidget(
        ProviderScope(
          child: CopaPalpiteApp(sessionController: sessionController),
        ),
      );
      await tester.tap(find.textContaining('Come'));
      await tester.pumpAndSettle();

      // Act / Assert
      expect(find.text('Fase de grupos'), findsOneWidget);

      await tester.tap(find.byTooltip('Matches'));
      await tester.pumpAndSettle();
      expect(find.text('Seus palpites'), findsOneWidget);

      await tester.tap(find.byTooltip('Ranking'));
      await tester.pumpAndSettle();
      expect(find.text('Leaderboard'), findsOneWidget);

      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile'), findsOneWidget);

      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      expect(find.text('Fase de grupos'), findsOneWidget);
    });
  });
}
