import 'package:copa_palpite/models/app_user.dart';
import 'package:copa_palpite/models/leaderboard_entry.dart';
import 'package:copa_palpite/models/match_prediction.dart';
import 'package:copa_palpite/services/leaderboard_service.dart';
import 'package:copa_palpite/services/prediction_service.dart';
import 'package:copa_palpite/services/session_controller.dart';
import 'package:copa_palpite/theme/app_theme.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';

const testUser = AppUser(
  id: 'user-1',
  email: 'user@example.com',
  displayName: 'User Test',
  nick: 'User Test',
  avatarId: 'star',
);

const futureMatch = MatchPrediction(
  fixtureId: 101,
  round: 'Group Stage - 1',
  kickoffLabel: '11 jun, 16:00',
  kickoffAt: '2099-06-11T19:00:00Z',
  homeTeam: 'Brazil',
  awayTeam: 'Germany',
  status: 'NS',
);

const lockedMatch = MatchPrediction(
  fixtureId: 102,
  round: 'Group Stage - 1',
  kickoffLabel: '11 jun, 16:00',
  kickoffAt: '2026-06-11T19:00:00Z',
  homeTeam: 'Mexico',
  awayTeam: 'South Africa',
  status: 'FT',
  homeScore: 2,
  awayScore: 1,
);

const savedPrediction = UserMatchPrediction(
  pick: MatchPick.home,
  homeScore: 2,
  awayScore: 1,
);

class MockPredictionService extends Mock implements PredictionService {}

class MockLeaderboardService extends Mock implements LeaderboardService {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseAppCheck extends Mock implements FirebaseAppCheck {}

class MockFirebaseUser extends Mock implements User {}

class MockFirebaseDatabase extends Mock implements FirebaseDatabase {}

class MockUserCredential extends Mock implements UserCredential {}

class TestSessionController extends SessionController {
  TestSessionController({
    AppUser? currentUser = testUser,
    this.googleSignInError,
    this.emailSignInError,
  }) : _currentUser = currentUser;

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  final String? googleSignInError;
  final String? emailSignInError;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  @override
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (googleSignInError != null) {
      _errorMessage = googleSignInError;
    } else {
      _currentUser = testUser;
      _errorMessage = null;
    }
    _setLoading(false);
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _emailFlow(email);
  }

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    await _emailFlow(email);
  }

  @override
  Future<void> updateProfile({
    required String nick,
    required String avatarId,
    String? photoUrl,
  }) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(
      nick: nick,
      avatarId: avatarId,
      photoUrl: photoUrl,
    );
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _emailFlow(String email) async {
    _setLoading(true);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (emailSignInError != null) {
      _errorMessage = emailSignInError;
    } else {
      _currentUser = testUser.copyWith(
        email: email,
        displayName: email.split('@').first,
      );
      _errorMessage = null;
    }
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

Widget buildTestApp(Widget child) {
  return ProviderScope(
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

void registerTestFallbackValues() {
  registerFallbackValue(testUser);
  registerFallbackValue(futureMatch);
  registerFallbackValue(savedPrediction);
}

List<LeaderboardEntry> leaderboardEntries() {
  return const [
    LeaderboardEntry(
      position: 1,
      userId: 'user-2',
      nick: 'Canarinho',
      avatarId: 'cup',
      points: 12,
      predictionsCount: 4,
      exactScores: 2,
    ),
    LeaderboardEntry(
      position: 2,
      userId: 'user-1',
      nick: 'User Test',
      avatarId: 'star',
      points: 9,
      predictionsCount: 3,
      exactScores: 1,
      isCurrentUser: true,
    ),
    LeaderboardEntry(
      position: 3,
      userId: 'user-3',
      nick: 'Hexa',
      avatarId: 'ball',
      points: 7,
      predictionsCount: 3,
      exactScores: 1,
    ),
  ];
}
