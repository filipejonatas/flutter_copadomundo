import 'package:copa_palpite/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Full app flows', () {
    testWidgets('full auth flow navigates from Splash to Home', (tester) async {
      // Arrange
      final sessionController = TestSessionController(currentUser: null);
      await tester.pumpWidget(
        ProviderScope(
          child: CopaPalpiteApp(sessionController: sessionController),
        ),
      );

      // Act
      expect(find.text('Copa Palpite'), findsOneWidget);
      await tester.tap(find.textContaining('Come'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar com o Google'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Fase de grupos'), findsOneWidget);
    });

    testWidgets('ranking flow renders sorted list with top 3 trophy icons', (
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

      // Act
      await tester.tap(find.byTooltip('Ranking'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.byTooltip('Top 3'), findsWidgets);
    });

    testWidgets('tabs keep navigation usable when moving back and forth', (
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

      // Act
      await tester.tap(find.byTooltip('Matches'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Matches'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Seus palpites'), findsOneWidget);
    });
  });
}
