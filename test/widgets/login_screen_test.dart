import 'dart:async';

import 'package:copa_palpite/models/app_user.dart';
import 'package:copa_palpite/screens/login_screen.dart';
import 'package:copa_palpite/services/session_controller.dart';
import 'package:copa_palpite/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('LoginPage', () {
    testWidgets('should render Google Sign-In button', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildLoginApp(TestSessionController(currentUser: null)),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Continuar com o Google'), findsOneWidget);
    });

    testWidgets('should show CircularProgressIndicator while loading', (
      tester,
    ) async {
      // Arrange
      final sessionController = PendingSessionController();
      await tester.pumpWidget(buildLoginApp(sessionController));
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Continuar com o Google'));
      await tester.pump();

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      sessionController.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('should show SnackBar on login error', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildLoginApp(
          TestSessionController(
            currentUser: null,
            googleSignInError: 'Nao foi possivel entrar com Google.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Continuar com o Google'));
      await tester.pump(const Duration(milliseconds: 1300));

      // Assert
      expect(find.text('Nao foi possivel entrar com Google.'), findsOneWidget);
    });

    testWidgets('should navigate to Home on successful login', (tester) async {
      // Arrange
      await tester.pumpWidget(
        buildLoginApp(TestSessionController(currentUser: null)),
      );
      await tester.pumpAndSettle();

      // Act
      await tester.tap(find.text('Continuar com o Google'));
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Home'), findsOneWidget);
    });
  });
}

Widget buildLoginApp(SessionController sessionController) {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            LoginPage(sessionController: sessionController),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home')),
      ),
    ],
  );

  return ProviderScope(
    child: MaterialApp.router(theme: AppTheme.dark(), routerConfig: router),
  );
}

class PendingSessionController extends SessionController {
  final Completer<void> _completer = Completer<void>();
  AppUser? _currentUser;
  bool _isLoading = false;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => null;

  @override
  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    await _completer.future;
    _currentUser = testUser;
    _isLoading = false;
    notifyListeners();
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> updateProfile({
    required String nick,
    required String avatarId,
    String? photoUrl,
  }) async {}

  @override
  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }

  void complete() {
    _completer.complete();
  }
}
