import 'dart:convert';

import 'package:copa_palpite/models/match_prediction.dart';
import 'package:copa_palpite/services/prediction_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/test_helpers.dart';

void main() {
  setUpAll(registerTestFallbackValues);

  group('PredictionService', () {
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
      when(
        () => appCheck.getLimitedUseToken(),
      ).thenAnswer((_) async => 'limited-app-check-token');
    });

    test('should save prediction correctly to backend', () async {
      // Arrange
      late http.Request capturedRequest;
      final service = PredictionService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response('{}', 201);
        }),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act
      await service.savePrediction(
        user: testUser,
        match: futureMatch,
        prediction: savedPrediction,
      );

      // Assert
      expect(capturedRequest.method, 'POST');
      expect(capturedRequest.url.path, '/predictions');
      expect(capturedRequest.headers['Authorization'], 'Bearer id-token');
      expect(capturedRequest.headers['X-Firebase-AppCheck'], 'app-check-token');
      expect(jsonDecode(capturedRequest.body), {
        'fixtureId': 101,
        'pick': 'home',
        'homeScore': 2,
        'awayScore': 1,
      });
    });

    test('should load matches from backend', () async {
      // Arrange
      final service = PredictionService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/matches/world-cup-2026');
          return http.Response(
            jsonEncode([
              {
                'fixtureId': 101,
                'round': 'Group Stage - 1',
                'kickoffLabel': '11 jun, 16:00',
                'kickoffAt': '2099-06-11T19:00:00Z',
                'homeTeam': 'Brazil',
                'awayTeam': 'Germany',
                'status': 'NS',
              },
            ]),
            200,
          );
        }),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act
      final matches = await service.loadMatches();

      // Assert
      expect(matches, hasLength(1));
      expect(matches.single.fixtureId, 101);
      expect(matches.single.homeTeam, 'Brazil');
    });

    test('should throw when loadMatches backend returns error', () async {
      // Arrange
      final service = PredictionService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async => http.Response('{}', 500)),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act / Assert
      await expectLater(service.loadMatches(), throwsA(isA<Exception>()));
    });

    test('should load user predictions with secure headers', () async {
      // Arrange
      late http.Request capturedRequest;
      final service = PredictionService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async {
          capturedRequest = request;
          return http.Response(
            jsonEncode({
              '101': {'pick': 'draw', 'homeScore': 1, 'awayScore': 1},
            }),
            200,
          );
        }),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act
      final predictions = await service.loadUserPredictions(testUser);

      // Assert
      expect(capturedRequest.url.path, '/predictions/me');
      expect(capturedRequest.headers['Authorization'], 'Bearer id-token');
      expect(capturedRequest.headers['X-Firebase-AppCheck'], 'app-check-token');
      expect(predictions[101]?.pick, MatchPick.draw);
    });

    test('should throw when auth token is unavailable', () async {
      // Arrange
      when(() => firebaseUser.getIdToken()).thenAnswer((_) async => null);
      final service = PredictionService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async => http.Response('{}', 200)),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act / Assert
      await expectLater(
        service.loadUserPredictions(testUser),
        throwsA(isA<StateError>()),
      );
    });

    test('should throw when App Check token is unavailable', () async {
      // Arrange
      when(() => appCheck.getToken()).thenAnswer((_) async => '');
      final service = PredictionService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async => http.Response('{}', 200)),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act / Assert
      await expectLater(
        service.loadUserPredictions(testUser),
        throwsA(isA<StateError>()),
      );
    });

    test('should not allow prediction after match start time', () async {
      // Arrange
      var calledBackend = false;
      final service = PredictionService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async {
          calledBackend = true;
          return http.Response('{}', 201);
        }),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act / Assert
      await expectLater(
        service.savePrediction(
          user: testUser,
          match: lockedMatch,
          prediction: savedPrediction,
        ),
        throwsA(isA<StateError>()),
      );
      expect(calledBackend, isFalse);
    });

    test('should reject invalid score before saving', () async {
      // Arrange
      var calledBackend = false;
      final service = PredictionService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((request) async {
          calledBackend = true;
          return http.Response('{}', 201);
        }),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act / Assert
      await expectLater(
        service.savePrediction(
          user: testUser,
          match: futureMatch,
          prediction: const UserMatchPrediction(
            pick: MatchPick.home,
            homeScore: 10,
            awayScore: 1,
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(calledBackend, isFalse);
    });

    test('should parse user predictions by fixture id', () {
      // Arrange
      final service = PredictionService(
        firebaseAuth: auth,
        firebaseAppCheck: appCheck,
        httpClient: MockClient((_) async => http.Response('{}', 200)),
        apiBaseUrl: 'https://api.example.test',
      );

      // Act
      final predictions = service.parseUserPredictions({
        '101': {'pick': 'home', 'homeScore': '2', 'awayScore': 1},
        'bad-id': {'pick': 'away'},
        '102': {'pick': 'invalid'},
      });

      // Assert
      expect(predictions.keys, [101]);
      expect(predictions[101]?.pick, MatchPick.home);
      expect(predictions[101]?.homeScore, 2);
      expect(predictions[101]?.awayScore, 1);
    });
  });

  group('Prediction points', () {
    test('should calculate exact score as 3 points', () {
      // Arrange
      const prediction = UserMatchPrediction(
        pick: MatchPick.home,
        homeScore: 2,
        awayScore: 1,
      );

      // Act
      final points = calculatePredictionPoints(
        prediction: prediction,
        actualHomeScore: 2,
        actualAwayScore: 1,
      );

      // Assert
      expect(points, 3);
    });

    test('should calculate correct winner only as 1 point', () {
      // Arrange
      const prediction = UserMatchPrediction(
        pick: MatchPick.home,
        homeScore: 3,
        awayScore: 1,
      );

      // Act
      final points = calculatePredictionPoints(
        prediction: prediction,
        actualHomeScore: 2,
        actualAwayScore: 1,
      );

      // Assert
      expect(points, 1);
    });

    test('should calculate wrong prediction as 0 points', () {
      // Arrange
      const prediction = UserMatchPrediction(
        pick: MatchPick.away,
        homeScore: 0,
        awayScore: 1,
      );

      // Act
      final points = calculatePredictionPoints(
        prediction: prediction,
        actualHomeScore: 2,
        actualAwayScore: 1,
      );

      // Assert
      expect(points, 0);
    });
  });
}
