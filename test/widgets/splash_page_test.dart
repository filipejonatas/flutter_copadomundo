import 'package:copa_palpite/screens/splash_page.dart';
import 'package:copa_palpite/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('SplashPage', () {
    testWidgets(
      'should render trophy image, app name, subtitle, and start button',
      (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.dark(), home: const SplashPage()),
        );

        // Act
        await tester.pumpAndSettle();

        // Assert
        expect(find.byType(Image), findsOneWidget);
        expect(find.text('Copa Palpite'), findsOneWidget);
        expect(find.textContaining('palpites da Copa 2026'), findsOneWidget);
        expect(find.textContaining('Come'), findsOneWidget);
      },
    );

    testWidgets('should trigger navigation on button tap', (tester) async {
      // Arrange
      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const SplashPage(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const Scaffold(body: Text('Login')),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
      );

      // Act
      await tester.tap(find.textContaining('Come'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Login'), findsOneWidget);
    });
  });
}
