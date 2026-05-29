import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/match_prediction.dart';

class PredictionService {
  PredictionService({
    FirebaseDatabase? database,
    http.Client? httpClient,
    this.apiBaseUrl = 'http://127.0.0.1:3000',
  }) : _database = database ?? FirebaseDatabase.instance,
       _httpClient = httpClient ?? http.Client();

  final FirebaseDatabase _database;
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

  Future<Map<int, MatchPick>> loadUserPredictions(AppUser user) async {
    final snapshot = await _userPredictionsReference(user.id).get();
    final rawData = snapshot.value;
    if (rawData is! Map) return <int, MatchPick>{};

    final predictions = <int, MatchPick>{};
    for (final entry in rawData.entries) {
      final fixtureId = int.tryParse(entry.key.toString());
      final value = entry.value;
      if (fixtureId == null || value is! Map) continue;

      final pick = pickFromStorageValue(value['pick']);
      if (pick != null) {
        predictions[fixtureId] = pick;
      }
    }

    return predictions;
  }

  Future<void> savePrediction({
    required AppUser user,
    required MatchPrediction match,
    required MatchPick pick,
  }) async {
    await _userPredictionsReference(user.id).child('${match.fixtureId}').set({
      'fixtureId': match.fixtureId,
      'pick': pickToStorageValue(pick),
      'round': match.round,
      'homeTeam': match.homeTeam,
      'awayTeam': match.awayTeam,
      'updatedAt': ServerValue.timestamp,
    });
  }

  DatabaseReference _userPredictionsReference(String uid) {
    return _database.ref('predictions/$uid');
  }
}
