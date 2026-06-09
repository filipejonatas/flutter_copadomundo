import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/match_prediction.dart';

class PredictionService {
  PredictionService({
    FirebaseAuth? firebaseAuth,
    http.Client? httpClient,
    this.apiBaseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:3000',
    ),
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _httpClient = httpClient ?? http.Client();

  final FirebaseAuth _firebaseAuth;
  final http.Client _httpClient;
  final String apiBaseUrl;

  Future<List<MatchPrediction>> loadMatches() async {
    final uri = Uri.parse('$apiBaseUrl/matches/world-cup-2026');
    final response = await _httpClient.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Backend retornou status ${response.statusCode}.');
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
      Uri.parse('$apiBaseUrl/predictions/me'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend retornou status ${response.statusCode}.');
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
      Uri.parse('$apiBaseUrl/predictions'),
      headers: {...await _authHeaders(), 'Content-Type': 'application/json'},
      body: jsonEncode({
        'fixtureId': match.fixtureId,
        'pick': pickToStorageValue(prediction.pick),
        'homeScore': prediction.homeScore,
        'awayScore': prediction.awayScore,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Backend retornou status ${response.statusCode}.');
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _firebaseAuth.currentUser?.getIdToken();
    if (token == null) {
      throw StateError('Entre novamente para continuar.');
    }

    return {'Authorization': 'Bearer $token'};
  }
}
