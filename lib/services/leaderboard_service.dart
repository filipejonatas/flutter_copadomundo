import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/leaderboard_entry.dart';

class LeaderboardService {
  LeaderboardService({
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

  Future<List<LeaderboardEntry>> loadLeaderboard(AppUser currentUser) async {
    if (currentUser.id.startsWith('mock-')) {
      return [_mockEntry(currentUser)];
    }

    final response = await _httpClient.get(
      Uri.parse('$apiBaseUrl/leaderboard'),
      headers: await _authHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception('Backend retornou status ${response.statusCode}.');
    }

    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload.map((item) {
      final data = item as Map<String, dynamic>;
      final userId = data['userId'] as String;
      return LeaderboardEntry(
        position: data['position'] as int,
        userId: userId,
        nick: data['nick'] as String,
        avatarId: data['avatarId'] as String,
        points: data['points'] as int,
        predictionsCount: data['predictionsCount'] as int,
        exactScores: data['exactScores'] as int,
        isCurrentUser: userId == currentUser.id,
      );
    }).toList();
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _firebaseAuth.currentUser?.getIdToken();
    if (token == null) {
      throw StateError('Entre novamente para continuar.');
    }

    return {'Authorization': 'Bearer $token'};
  }

  LeaderboardEntry _mockEntry(AppUser user) {
    return LeaderboardEntry(
      position: 1,
      userId: user.id,
      nick: user.nick,
      avatarId: user.avatarId,
      points: 0,
      predictionsCount: 0,
      exactScores: 0,
      isCurrentUser: true,
    );
  }
}
