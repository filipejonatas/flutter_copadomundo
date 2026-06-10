import 'dart:convert';

import 'package:copa_palpite/services/leaderboard_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/test_helpers.dart';

void main() {
  group('LeaderboardService', () {
    late MockFirebaseAuth auth;
    late MockFirebaseAppCheck appCheck;
    late MockFirebaseUser firebaseUser;

    setUp(() {
      auth = MockFirebaseAuth();
      appCheck = MockFirebaseAppCheck();
      firebaseUser = MockFirebaseUser();

      when(() => auth.currentUser).thenReturn(firebaseUser);
      when(() => firebaseUser.getIdToken()).thenAnswer((_) async => 'id-token');
      when(
        () => appCheck.getToken(),
      ).thenAnswer((_) async => 'app-check-token');
    });

    test('should return ranked list sorted by points descending', () async {
      // Arrange
      final service = LeaderboardService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async {
          expect(request.url.path, '/leaderboard');
          return http.Response(
            jsonEncode([
              {
                'position': 1,
                'userId': 'u1',
                'nick': 'Top',
                'avatarId': 'cup',
                'points': 10,
                'predictionsCount': 3,
                'exactScores': 2,
              },
              {
                'position': 2,
                'userId': 'user-1',
                'nick': 'User Test',
                'avatarId': 'star',
                'points': 8,
                'predictionsCount': 3,
                'exactScores': 1,
              },
            ]),
            200,
          );
        }),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act
      final entries = await service.loadLeaderboard(testUser);

      // Assert
      expect(entries.map((entry) => entry.points), [10, 8]);
      expect(entries.last.isCurrentUser, isTrue);
    });

    test('should preserve backend tie-breaking order', () async {
      // Arrange
      final service = LeaderboardService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode([
              {
                'position': 1,
                'userId': 'u1',
                'nick': 'A',
                'avatarId': 'cup',
                'points': 10,
                'predictionsCount': 4,
                'exactScores': 2,
              },
              {
                'position': 2,
                'userId': 'u2',
                'nick': 'B',
                'avatarId': 'ball',
                'points': 10,
                'predictionsCount': 4,
                'exactScores': 1,
              },
            ]),
            200,
          );
        }),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act
      final entries = await service.loadLeaderboard(testUser);

      // Assert
      expect(entries.map((entry) => entry.position), [1, 2]);
      expect(entries.map((entry) => entry.nick), ['A', 'B']);
    });

    test('should return empty list when no predictions exist', () async {
      // Arrange
      final service = LeaderboardService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async => http.Response('[]', 200)),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act
      final entries = await service.loadLeaderboard(testUser);

      // Assert
      expect(entries, isEmpty);
    });

    test('should throw when backend returns error', () async {
      // Arrange
      final service = LeaderboardService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async => http.Response('{}', 500)),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act / Assert
      await expectLater(
        service.loadLeaderboard(testUser),
        throwsA(isA<Exception>()),
      );
    });

    test('should throw when auth token is unavailable', () async {
      // Arrange
      when(() => firebaseUser.getIdToken()).thenAnswer((_) async => null);
      final service = LeaderboardService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async => http.Response('[]', 200)),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act / Assert
      await expectLater(
        service.loadLeaderboard(testUser),
        throwsA(isA<StateError>()),
      );
    });

    test('should throw when App Check token is unavailable', () async {
      // Arrange
      when(() => appCheck.getToken()).thenAnswer((_) async => '');
      final service = LeaderboardService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async => http.Response('[]', 200)),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act / Assert
      await expectLater(
        service.loadLeaderboard(testUser),
        throwsA(isA<StateError>()),
      );
    });
  });
}
