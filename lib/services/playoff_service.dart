import 'dart:convert';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/playoff.dart';
import 'app_check_config.dart';
import 'api_config.dart';

class PlayoffService {
  PlayoffService({
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

  Future<PlayoffBracket?> loadCurrentBracket() async {
    final response = await _httpClient.get(
      _apiBaseUri.resolve('/playoffs/current'),
      headers: await _secureHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_backendError(response));
    }
    if (response.body.trim() == 'null' || response.body.trim().isEmpty) {
      return null;
    }

    return PlayoffBracket.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<List<PlayoffRoundScore>> loadRoundScore(String round) async {
    final response = await _httpClient.get(
      _apiBaseUri
          .resolve('/playoffs/current/round-score')
          .replace(queryParameters: {'round': round}),
      headers: await _secureHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(_backendError(response));
    }

    final payload = jsonDecode(response.body) as List<dynamic>;
    return payload
        .map((item) => PlayoffRoundScore.fromJson(item as Map<String, dynamic>))
        .toList();
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
}
