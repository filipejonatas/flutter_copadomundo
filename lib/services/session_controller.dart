import 'package:flutter/foundation.dart';

import '../models/app_user.dart';

abstract class SessionController extends ChangeNotifier {
  AppUser? get currentUser;
  bool get isLoading;

  Future<void> signInWithGoogle();
  Future<void> updateProfile({required String nick, required String avatarId});
  Future<void> signOut();
}

class MockSessionController extends SessionController {
  AppUser? _currentUser;
  bool _isLoading = false;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  bool get isLoading => _isLoading;

  @override
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _currentUser = const AppUser(
      id: 'mock-google-user',
      email: 'usuario@gmail.com',
      displayName: 'Usuario Google',
      nick: 'Novo Palpiteiro',
      avatarId: 'star',
    );
    _setLoading(false);
  }

  @override
  Future<void> updateProfile({
    required String nick,
    required String avatarId,
  }) async {
    if (_currentUser == null) return;

    _setLoading(true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _currentUser = _currentUser!.copyWith(
      nick: nick.trim(),
      avatarId: avatarId,
    );
    _setLoading(false);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
