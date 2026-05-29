import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';

abstract class SessionController extends ChangeNotifier {
  AppUser? get currentUser;
  bool get isLoading;
  String? get errorMessage;

  Future<void> signInWithGoogle();
  Future<void> updateProfile({required String nick, required String avatarId});
  Future<void> signOut();
}

class FirebaseSessionController extends SessionController {
  FirebaseSessionController({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance {
    _authSubscription = _firebaseAuth.userChanges().listen(_syncFirebaseUser);
    unawaited(GoogleSignIn.instance.initialize());
  }

  final FirebaseAuth _firebaseAuth;
  StreamSubscription<User?>? _authSubscription;
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String _avatarId = 'star';

  @override
  AppUser? get currentUser => _currentUser;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

  @override
  Future<void> signInWithGoogle() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      if (kIsWeb) {
        await _firebaseAuth.signInWithPopup(GoogleAuthProvider());
      } else {
        final googleUser = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleUser.authentication;

        if (googleAuth.idToken == null) {
          throw FirebaseAuthException(
            code: 'missing-google-id-token',
            message: 'O Google nao retornou um token de autenticacao.',
          );
        }

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );
        await _firebaseAuth.signInWithCredential(credential);
      }
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled) {
        _errorMessage = 'Nao foi possivel entrar com Google.';
      }
    } on FirebaseAuthException catch (error) {
      _errorMessage = error.message ?? 'Nao foi possivel autenticar.';
    } catch (_) {
      _errorMessage = 'Nao foi possivel entrar. Tente novamente.';
    } finally {
      _setLoading(false);
    }
  }

  @override
  Future<void> updateProfile({
    required String nick,
    required String avatarId,
  }) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) return;

    _setLoading(true);
    _errorMessage = null;

    try {
      await firebaseUser.updateDisplayName(nick.trim());
      await firebaseUser.reload();
      _avatarId = avatarId;
      _syncFirebaseUser(_firebaseAuth.currentUser);
    } on FirebaseAuthException catch (error) {
      _errorMessage = error.message ?? 'Nao foi possivel salvar o perfil.';
    } catch (_) {
      _errorMessage = 'Nao foi possivel salvar o perfil.';
    } finally {
      _setLoading(false);
    }
  }

  @override
  Future<void> signOut() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await GoogleSignIn.instance.signOut();
      await _firebaseAuth.signOut();
    } finally {
      _currentUser = null;
      _setLoading(false);
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  void _syncFirebaseUser(User? user) {
    _currentUser = user == null ? null : _mapFirebaseUser(user);
    notifyListeners();
  }

  AppUser _mapFirebaseUser(User user) {
    final fallbackNick = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!.trim()
        : user.email?.split('@').first ?? 'Palpiteiro';

    return AppUser(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? fallbackNick,
      nick: fallbackNick,
      avatarId: _avatarId,
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

class MockSessionController extends SessionController {
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  bool get isLoading => _isLoading;

  @override
  String? get errorMessage => _errorMessage;

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
