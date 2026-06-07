import 'package:firebase_database/firebase_database.dart';

import '../models/app_user.dart';
import '../models/leaderboard_entry.dart';
import '../models/match_prediction.dart';

class LeaderboardService {
  LeaderboardService({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  static const int pointsPerPrediction = 3;

  Future<List<LeaderboardEntry>> loadLeaderboard(AppUser currentUser) async {
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
      final userPredictions = _asMap(predictions[userId]);
      final predictionsCount = _validPredictionsCount(userPredictions);
      final isCurrentUser = userId == currentUser.id;

      entries.add(
        LeaderboardEntry(
          position: 0,
          userId: userId,
          nick:
              _stringValue(profile['nick']) ??
              (isCurrentUser ? currentUser.nick : 'Palpiteiro'),
          avatarId:
              _stringValue(profile['avatarId']) ??
              (isCurrentUser ? currentUser.avatarId : 'star'),
          points: predictionsCount * pointsPerPrediction,
          predictionsCount: predictionsCount,
          exactScores: 0,
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

  int _validPredictionsCount(Map<String, dynamic> predictions) {
    var total = 0;

    for (final value in predictions.values) {
      final prediction = _asMap(value);
      if (pickFromStorageValue(prediction['pick']) != null) {
        total++;
      }
    }

    return total;
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
