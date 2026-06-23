import '../models/match_prediction.dart';

int initialMatchDayIndex(
  List<List<MatchPrediction>> matchDays, {
  DateTime? now,
}) {
  if (matchDays.isEmpty) return 0;

  final reference = now ?? DateTime.now();
  final today = _dateOnly(reference.toLocal());

  for (var index = 0; index < matchDays.length; index++) {
    if (matchDays[index].any((match) => _matchDate(match) == today)) {
      return index;
    }
  }

  for (var index = 0; index < matchDays.length; index++) {
    final hasFutureMatch = matchDays[index].any((match) {
      final date = _matchDate(match);
      return date != null && date.isAfter(today);
    });
    if (hasFutureMatch) return index;
  }

  for (var index = matchDays.length - 1; index >= 0; index--) {
    if (matchDays[index].any((match) => _matchDate(match) != null)) {
      return index;
    }
  }

  return 0;
}

DateTime? _matchDate(MatchPrediction match) {
  final kickoff = DateTime.tryParse(match.kickoffAt);
  if (kickoff == null) return null;
  return _dateOnly(kickoff.toLocal());
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}
