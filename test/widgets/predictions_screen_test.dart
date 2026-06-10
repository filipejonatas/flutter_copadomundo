import 'package:copa_palpite/models/match_prediction.dart';
import 'package:copa_palpite/screens/predictions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpAll(registerTestFallbackValues);

  group('PredictionsScreen', () {
    late MockPredictionService predictionService;
    late TestSessionController sessionController;

    setUp(() {
      predictionService = MockPredictionService();
      sessionController = TestSessionController();
    });

    testWidgets('should render plus and minus buttons for each team', (
      tester,
    ) async {
      // Arrange
      _stubPredictions(
        predictionService,
        matches: [futureMatch],
        predictions: {},
      );

      // Act
      await tester.pumpWidget(
        _buildScreen(sessionController, predictionService),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byTooltip('Aumentar'), findsNWidgets(2));
      expect(find.byTooltip('Diminuir'), findsNWidgets(2));
    });

    testWidgets('should not allow score below 0', (tester) async {
      // Arrange
      _stubPredictions(
        predictionService,
        matches: [futureMatch],
        predictions: {},
      );
      await tester.pumpWidget(
        _buildScreen(sessionController, predictionService),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.byTooltip('Diminuir').first);
      await tester.pump();

      // Assert
      expect(find.text('-1'), findsNothing);
      expect(find.text('0'), findsWidgets);
    });

    testWidgets('should not allow score above 9', (tester) async {
      // Arrange
      _stubPredictions(
        predictionService,
        matches: [futureMatch],
        predictions: {},
      );
      await tester.pumpWidget(
        _buildScreen(sessionController, predictionService),
      );
      await tester.pumpAndSettle();

      // Act
      for (var i = 0; i < 12; i++) {
        await tester.tap(find.byTooltip('Aumentar').first);
        await tester.pump();
      }

      // Assert
      expect(find.text('9'), findsOneWidget);
      expect(find.text('10'), findsNothing);
    });

    testWidgets('should disable confirm button if match already started', (
      tester,
    ) async {
      // Arrange
      _stubPredictions(
        predictionService,
        matches: [lockedMatch],
        predictions: {},
      );

      // Act
      await tester.pumpWidget(
        _buildScreen(sessionController, predictionService),
      );
      await tester.pumpAndSettle();
      await _scrollToConfirmButton(tester);

      // Assert
      final button = tester.widget<FilledButton>(_confirmButtonFinder());
      expect(button.onPressed, isNull);
      expect(find.text('Palpites encerrados para este jogo.'), findsOneWidget);
    });

    testWidgets('should show existing prediction in read-only mode', (
      tester,
    ) async {
      // Arrange
      _stubPredictions(
        predictionService,
        matches: [futureMatch],
        predictions: {futureMatch.fixtureId: savedPrediction},
      );

      // Act
      await tester.pumpWidget(
        _buildScreen(sessionController, predictionService),
      );
      await tester.pumpAndSettle();
      await _scrollToConfirmButton(tester);

      // Assert
      final button = tester.widget<FilledButton>(_confirmButtonFinder());
      expect(button.onPressed, isNull);
      expect(find.text('Salvo: Brazil (2 x 1)'), findsOneWidget);
    });

    testWidgets('should call PredictionService.savePrediction on confirm tap', (
      tester,
    ) async {
      // Arrange
      _stubPredictions(
        predictionService,
        matches: [futureMatch],
        predictions: {},
      );
      when(
        () => predictionService.savePrediction(
          user: any(named: 'user'),
          match: any(named: 'match'),
          prediction: any(named: 'prediction'),
        ),
      ).thenAnswer((_) async {});
      await tester.pumpWidget(
        _buildScreen(sessionController, predictionService),
      );
      await tester.pumpAndSettle();
      await _scrollToConfirmButton(tester);

      // Act
      await tester.tap(_confirmButtonFinder());
      await tester.pumpAndSettle();

      // Assert
      verify(
        () => predictionService.savePrediction(
          user: testUser,
          match: futureMatch,
          prediction: any(named: 'prediction'),
        ),
      ).called(1);
      expect(find.text('Palpite salvo.'), findsOneWidget);
    });
  });
}

Widget _buildScreen(
  TestSessionController sessionController,
  MockPredictionService predictionService,
) {
  return buildTestApp(
    PredictionsScreen(
      sessionController: sessionController,
      predictionService: predictionService,
    ),
  );
}

Future<void> _scrollToConfirmButton(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.text('Confirmar palpite'),
    160,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Finder _confirmButtonFinder() {
  return find.byWidgetPredicate((widget) => widget is FilledButton);
}

void _stubPredictions(
  MockPredictionService predictionService, {
  required List<MatchPrediction> matches,
  required Map<int, UserMatchPrediction> predictions,
}) {
  when(() => predictionService.loadMatches()).thenAnswer((_) async => matches);
  when(
    () => predictionService.loadUserPredictions(any()),
  ).thenAnswer((_) async => predictions);
}
