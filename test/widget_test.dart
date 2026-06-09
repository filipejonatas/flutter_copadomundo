import 'package:copa_palpite/main.dart';
import 'package:copa_palpite/services/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('login, profile and leaderboard flow works', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: CopaPalpiteApp(sessionController: MockSessionController()),
      ),
    );

    expect(find.text('Copa Palpite'), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);

    await tester.tap(find.text('Começar'));
    await tester.pumpAndSettle();

    expect(find.text('Copa Palpite'), findsOneWidget);
    expect(find.text('Continuar com o Google'), findsOneWidget);

    await tester.tap(find.text('Continuar com o Google'));
    await tester.pumpAndSettle();

    expect(find.text('Fase de grupos'), findsOneWidget);

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Novo Palpiteiro'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Craque Teste');
    await tester.scrollUntilVisible(
      find.text('Salvar perfil'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Salvar perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Craque Teste'), findsWidgets);

    await tester.tap(find.byTooltip('Ranking'));
    await tester.pumpAndSettle();

    expect(find.text('Leaderboard'), findsOneWidget);
    expect(find.text('Craque Teste'), findsOneWidget);
  });
}
