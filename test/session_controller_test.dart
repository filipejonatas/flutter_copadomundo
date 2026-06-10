import 'package:copa_palpite/services/session_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('FirebaseSessionController', () {
    late MockFirebaseAuth auth;
    late MockFirebaseDatabase database;
    late MockFirebaseUser firebaseUser;
    late MockUserCredential credential;

    setUp(() {
      auth = MockFirebaseAuth();
      database = MockFirebaseDatabase();
      firebaseUser = MockFirebaseUser();
      credential = MockUserCredential();

      when(() => auth.userChanges()).thenAnswer((_) => const Stream.empty());
      when(() => auth.currentUser).thenReturn(null);
      when(() => credential.user).thenReturn(firebaseUser);
      when(() => firebaseUser.displayName).thenReturn(null);
      when(
        () => firebaseUser.updateDisplayName(any()),
      ).thenAnswer((_) async {});
    });

    test('should call FirebaseAuth on successful email sign-in', () async {
      // Arrange
      final controller = FirebaseSessionController(
        firebaseAuth: auth,
        database: database,
        enableGoogleSignIn: false,
      );
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);

      // Act
      await controller.signInWithEmail(
        email: ' user@example.com ',
        password: 'secret123',
      );

      // Assert
      verify(
        () => auth.signInWithEmailAndPassword(
          email: 'user@example.com',
          password: 'secret123',
        ),
      ).called(1);
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, isNull);

      controller.dispose();
    });

    test('should map invalid email sign-in error', () async {
      // Arrange
      final controller = FirebaseSessionController(
        firebaseAuth: auth,
        database: database,
        enableGoogleSignIn: false,
      );
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'invalid-email'));

      // Act
      await controller.signInWithEmail(email: 'invalid', password: 'secret123');

      // Assert
      expect(controller.isLoading, isFalse);
      expect(controller.errorMessage, 'Informe um email valido.');

      controller.dispose();
    });

    test('should map network sign-in error', () async {
      // Arrange
      final controller = FirebaseSessionController(
        firebaseAuth: auth,
        database: database,
        enableGoogleSignIn: false,
      );
      when(
        () => auth.signInWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'network-request-failed'));

      // Act
      await controller.signInWithEmail(
        email: 'user@example.com',
        password: 'secret123',
      );

      // Assert
      expect(
        controller.errorMessage,
        'Verifique sua conexao e tente novamente.',
      );

      controller.dispose();
    });

    test('should create account and set fallback display name', () async {
      // Arrange
      final controller = FirebaseSessionController(
        firebaseAuth: auth,
        database: database,
        enableGoogleSignIn: false,
      );
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => credential);

      // Act
      await controller.createAccountWithEmail(
        email: ' new-user@example.com ',
        password: 'secret123',
      );

      // Assert
      verify(
        () => auth.createUserWithEmailAndPassword(
          email: 'new-user@example.com',
          password: 'secret123',
        ),
      ).called(1);
      verify(() => firebaseUser.updateDisplayName('new-user')).called(1);
      expect(controller.errorMessage, isNull);

      controller.dispose();
    });

    test('should map weak password create account error', () async {
      // Arrange
      final controller = FirebaseSessionController(
        firebaseAuth: auth,
        database: database,
        enableGoogleSignIn: false,
      );
      when(
        () => auth.createUserWithEmailAndPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(FirebaseAuthException(code: 'weak-password'));

      // Act
      await controller.createAccountWithEmail(
        email: 'user@example.com',
        password: '123',
      );

      // Assert
      expect(
        controller.errorMessage,
        'Use uma senha com pelo menos 6 caracteres.',
      );

      controller.dispose();
    });

    test(
      'should set profile error when updating without logged user',
      () async {
        // Arrange
        final controller = FirebaseSessionController(
          firebaseAuth: auth,
          database: database,
          enableGoogleSignIn: false,
        );

        // Act
        await controller.updateProfile(nick: 'Craque', avatarId: 'cup');

        // Assert
        expect(
          controller.errorMessage,
          'Entre novamente para salvar o perfil.',
        );

        controller.dispose();
      },
    );

    test('should sign out and clear session', () async {
      // Arrange
      final controller = FirebaseSessionController(
        firebaseAuth: auth,
        database: database,
        enableGoogleSignIn: false,
      );
      when(() => auth.signOut()).thenAnswer((_) async {});

      // Act
      await controller.signOut();

      // Assert
      verify(() => auth.signOut()).called(1);
      expect(controller.currentUser, isNull);
      expect(controller.isLoading, isFalse);

      controller.dispose();
    });
  });
}
