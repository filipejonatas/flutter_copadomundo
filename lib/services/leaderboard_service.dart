import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/leaderboard_entry.dart';
import 'app_check_config.dart';
import 'api_config.dart';

class LeaderboardService {
  LeaderboardService({
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

  Future<List<LeaderboardEntry>> loadLeaderboard(AppUser currentUser) async {
    if (currentUser.id.startsWith('mock-')) {
      return [_mockEntry(currentUser)];
    }

    final response = await _httpClient.get(
      _apiBaseUri.resolve('/leaderboard'),
      headers: await _secureHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_backendError(response));
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
        photoUrl: data['photoUrl'] as String?,
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

  String _backendError(http.Response response) {
    final body = response.body.trim();
    if (body.isEmpty) return 'Backend retornou status ${response.statusCode}.';
    return 'Backend retornou status ${response.statusCode}: $body';
  }

  Future<Map<String, String>> _secureHeaders() async {
    final authHeaders = await _authHeaders();
    if (!shouldRequestAppCheckToken) return authHeaders;

    final appCheckToken = await _firebaseAppCheck.getToken();
    if (appCheckToken == null || appCheckToken.isEmpty) {
      throw StateError('App Check indisponivel. Tente novamente.');
    }

    return {...authHeaders, 'X-Firebase-AppCheck': appCheckToken};
  }

  LeaderboardEntry _mockEntry(AppUser user) {
    return LeaderboardEntry(
      position: 1,
      userId: user.id,
      nick: user.nick,
      avatarId: user.avatarId,
      photoUrl: user.photoUrl,
      points: 0,
      predictionsCount: 0,
      exactScores: 0,
      isCurrentUser: true,
    );
  }
}
