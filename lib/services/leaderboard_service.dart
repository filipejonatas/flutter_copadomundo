import 'package:firebase_database/firebase_database.dart';

import '../models/app_user.dart';
import '../models/leaderboard_entry.dart';
import '../models/match_prediction.dart';
import 'prediction_service.dart';

class LeaderboardService {
  LeaderboardService({
    FirebaseDatabase? database,
    PredictionService? predictionService,
  }) : _database = database ?? FirebaseDatabase.instance,
       _predictionService = predictionService ?? PredictionService();

  final FirebaseDatabase _database;
  final PredictionService _predictionService;

  static const int pointsPerExactScore = 5;
  static const int pointsPerCorrectPick = 3;

  Future<List<LeaderboardEntry>> loadLeaderboard(AppUser currentUser) async {
    final matches = await _predictionService.loadMatches();
    final finishedMatches = {
      for (final match in matches)
        if (_isFinished(match)) match.fixtureId: match,
    };
    final snapshots = await Future.wait([
      _database.ref('users').get(),
      _database.ref('predictions').get(),
    ]);

    final users = _asMap(snapshots[0].value);
    final predictions = _asMap(snapshots[1].value);
    final entries = <LeaderboardEntry>[];

    final userIds = <String>{...users.keys, ...predictions.keys};
    userIds.add(currentUser.id);

    for (final userId in userIds) {
      final profile = _asMap(users[userId]);
      final userPredictions = _predictionService.parseUserPredictions(
        predictions[userId],
      );
      final isCurrentUser = userId == currentUser.id;
      final nick =
          _stringValue(profile['nick']) ??
          (isCurrentUser ? currentUser.nick : 'Palpiteiro');
      final avatarId =
          _stringValue(profile['avatarId']) ??
          (isCurrentUser ? currentUser.avatarId : 'star');
      final score = _calculateScore(userPredictions, finishedMatches);

      await _persistScore(
        userId: userId,
        nick: nick,
        avatarId: avatarId,
        score: score,
      );

      entries.add(
        LeaderboardEntry(
          position: 0,
          userId: userId,
          nick: nick,
          avatarId: avatarId,
          points: score.points,
          predictionsCount: score.predictionsCount,
          exactScores: score.exactScores,
          isCurrentUser: isCurrentUser,
        ),
      );
    }

    entries.sort((a, b) {
      final pointsComparison = b.points.compareTo(a.points);
      if (pointsComparison != 0) return pointsComparison;
      final predictionsComparison = b.predictionsCount.compareTo(
        a.predictionsCount,
      );
      if (predictionsComparison != 0) return predictionsComparison;
      return a.nick.toLowerCase().compareTo(b.nick.toLowerCase());
    });

    return [
      for (var index = 0; index < entries.length; index++)
        entries[index].copyWith(position: index + 1),
    ];
  }

  _ConsolidatedScore _calculateScore(
    Map<int, UserMatchPrediction> predictions,
    Map<int, MatchPrediction> finishedMatches,
  ) {
    var points = 0;
    var predictionsCount = 0;
    var hits = 0;
    var exactScores = 0;
    final matchScores = <String, Map<String, Object?>>{};

    for (final entry in predictions.entries) {
      final match = finishedMatches[entry.key];
      if (match == null) continue;
      final prediction = entry.value;
      final actualPick = pickFromScore(match.homeScore!, match.awayScore!);
      final correctPick = prediction.pick == actualPick;
      final exactScore =
          correctPick &&
          prediction.homeScore == match.homeScore &&
          prediction.awayScore == match.awayScore;
      final matchPoints = exactScore
          ? pointsPerExactScore
          : correctPick
          ? pointsPerCorrectPick
          : 0;

      predictionsCount++;
      points += matchPoints;
      if (correctPick) hits++;
      if (exactScore) exactScores++;

      matchScores['${match.fixtureId}'] = {
        'fixtureId': match.fixtureId,
        'pick': pickToStorageValue(prediction.pick),
        'result': pickToStorageValue(actualPick),
        'homeScore': match.homeScore,
        'awayScore': match.awayScore,
        'predictedHomeScore': prediction.homeScore,
        'predictedAwayScore': prediction.awayScore,
        'points': matchPoints,
        'exactScore': exactScore,
      };
    }

    return _ConsolidatedScore(
      points: points,
      predictionsCount: predictionsCount,
      hits: hits,
      exactScores: exactScores,
      matchScores: matchScores,
    );
  }

  bool _isFinished(MatchPrediction match) {
    if (!match.hasResult) return false;

    return switch (match.status.toUpperCase()) {
      'FT' || 'FINAL' || 'FINISHED' || 'AET' || 'PEN' => true,
      _ => false,
    };
  }

  Future<void> _persistScore({
    required String userId,
    required String nick,
    required String avatarId,
    required _ConsolidatedScore score,
  }) {
    return _database.ref('scores/$userId').set({
      'userId': userId,
      'nick': nick,
      'avatarId': avatarId,
      'points': score.points,
      'predictionsCount': score.predictionsCount,
      'hits': score.hits,
      'exactScores': score.exactScores,
      'matches': score.matchScores,
      'updatedAt': ServerValue.timestamp,
    });
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is! Map) return <String, dynamic>{};
    return value.map((key, value) => MapEntry(key.toString(), value));
  }

  String? _stringValue(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

class _ConsolidatedScore {
  const _ConsolidatedScore({
    required this.points,
    required this.predictionsCount,
    required this.hits,
    required this.exactScores,
    required this.matchScores,
  });

  final int points;
  final int predictionsCount;
  final int hits;
  final int exactScores;
  final Map<String, Map<String, Object?>> matchScores;
}
