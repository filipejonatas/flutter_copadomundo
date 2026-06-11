import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/match_prediction.dart';
import 'app_check_config.dart';
import 'api_config.dart';

class PredictionService {
  PredictionService({
    FirebaseAuth? firebaseAuth,
    FirebaseAppCheck? firebaseAppCheck,
    http.Client? httpClient,
    this.apiBaseUrl = const String.fromEnvironment('API_BASE_URL'),
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _firebaseAppCheck = firebaseAppCheck ?? FirebaseAppCheck.instance,
       _httpClient = httpClient ?? http.Client(),
       _apiBaseUri = resolveApiBaseUri(apiBaseUrl);

  final FirebaseAuth _firebaseAuth;
  final FirebaseAppCheck _firebaseAppCheck;
  final http.Client _httpClient;
  final String apiBaseUrl;
  final Uri _apiBaseUri;

  Future<List<MatchPrediction>> loadMatches() async {
    final uri = _apiBaseUri.resolve('/matches/world-cup-2026');
    final response = await _httpClient.get(uri);

    if (response.statusCode != 200) {
      throw Exception(_backendError(response));
    }

    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((item) => MatchPrediction.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<int, UserMatchPrediction>> loadUserPredictions(
    AppUser user,
  ) async {
    if (user.id.startsWith('mock-')) return <int, UserMatchPrediction>{};

    final response = await _httpClient.get(
      _apiBaseUri.resolve('/predictions/me'),
      headers: await _secureHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_backendError(response));
    }

    return parseUserPredictions(jsonDecode(response.body));
  }

  Map<int, UserMatchPrediction> parseUserPredictions(Object? rawData) {
    if (rawData is! Map) return <int, UserMatchPrediction>{};

    final predictions = <int, UserMatchPrediction>{};
    for (final entry in rawData.entries) {
      final fixtureId = int.tryParse(entry.key.toString());
      final value = entry.value;
      if (fixtureId == null || value is! Map) continue;

      final prediction = userMatchPredictionFromMap(
        value.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (prediction != null) {
        predictions[fixtureId] = prediction;
      }
    }

    return predictions;
  }

  Future<void> savePrediction({
    required AppUser user,
    required MatchPrediction match,
    required UserMatchPrediction prediction,
  }) async {
    if (!match.isPredictionOpen()) {
      throw StateError('Palpites para este jogo ja estao encerrados.');
    }
    if (!isValidPredictionScore(prediction.homeScore) ||
        !isValidPredictionScore(prediction.awayScore)) {
      throw ArgumentError('Informe placares entre 0 e 9.');
    }

    final response = await _httpClient.post(
      _apiBaseUri.resolve('/predictions'),
      headers: {...await _secureHeaders(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'fixtureId': match.fixtureId,
        'pick': pickToStorageValue(prediction.pick),
        'homeScore': prediction.homeScore,
        'awayScore': prediction.awayScore,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_backendError(response));
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _firebaseAuth.currentUser?.getIdToken();
    if (token == null) {
      throw StateError('Entre novamente para continuar.');
    }

    return {'Authorization': 'Bearer $token'};
  }

  String _backendError(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return 'Backend retornou status ${response.statusCode}.';
    return 'Backend retornou status ${response.statusCode}: $body';
  }

  Future<Map<String, String>> _secureHeaders({
    bool limitedUseAppCheck = false,
  }) async {
    final authHeaders = await _authHeaders();
    if (!shouldRequestAppCheckToken) return authHeaders;

    final appCheckToken = limitedUseAppCheck
        ? await _firebaseAppCheck.getLimitedUseToken()
        : await _firebaseAppCheck.getToken();
    if (appCheckToken == null || appCheckToken.isEmpty) {
      throw StateError('App Check indisponivel. Tente novamente.');
    }

    return {...authHeaders, 'X-Firebase-AppCheck': appCheckToken};
  }
}
