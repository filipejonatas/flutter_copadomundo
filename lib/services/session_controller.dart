import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';

abstract class SessionController extends ChangeNotifier {
  AppUser? get currentUser;
  bool get isLoading;
  String? get errorMessage;

  Future<void> signInWithGoogle();
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  });
  Future<void> updateProfile({
    required String nick,
    required String avatarId,
    String? photoUrl,
  });
  Future<void> signOut();
}

class FirebaseSessionController extends SessionController {
  FirebaseSessionController({
    FirebaseAuth? firebaseAuth,
    FirebaseDatabase? database,
    bool enableGoogleSignIn = true,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _database = database ?? FirebaseDatabase.instance,
       _enableGoogleSignIn = enableGoogleSignIn {
    _authSubscription = _firebaseAuth.userChanges().listen(
      (user) => unawaited(_syncFirebaseUser(user)),
    );
    if (!kIsWeb && _enableGoogleSignIn) {
      unawaited(GoogleSignIn.instance.initialize());
    }
  }

  final FirebaseAuth _firebaseAuth;
  final FirebaseDatabase _database;
  final bool _enableGoogleSignIn;
  StreamSubscription<User?>? _authSubscription;
  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  int _authSyncVersion = 0;

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
        if (!_enableGoogleSignIn) {
          throw StateError('Google Sign-In indisponivel neste ambiente.');
        }
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
      _errorMessage = _authErrorMessage(
        error,
        fallback: 'Nao foi possivel autenticar.',
      );
    } catch (_) {
      _errorMessage = 'Nao foi possivel entrar. Tente novamente.';
    } finally {
      _setLoading(false);
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      _errorMessage = _authErrorMessage(
        error,
        fallback: 'Nao foi possivel entrar com email.',
      );
    } catch (_) {
      _errorMessage = 'Nao foi possivel entrar com email.';
    } finally {
      _setLoading(false);
    }
  }

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null &&
          (user.displayName == null || user.displayName!.isEmpty)) {
        await user.updateDisplayName(email.trim().split('@').first);
      }
    } on FirebaseAuthException catch (error) {
      _errorMessage = _authErrorMessage(
        error,
        fallback: 'Nao foi possivel criar sua conta.',
      );
    } catch (_) {
      _errorMessage = 'Nao foi possivel criar sua conta.';
    } finally {
      _setLoading(false);
    }
  }

  @override
  Future<void> updateProfile({
    required String nick,
    required String avatarId,
    String? photoUrl,
  }) async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null) {
      _errorMessage = 'Entre novamente para salvar o perfil.';
      notifyListeners();
      return;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      await firebaseUser.updateDisplayName(nick.trim());
      await _userReference(firebaseUser.uid).update({
        'nick': nick.trim(),
        'avatarId': avatarId,
        'email': firebaseUser.email ?? '',
        'displayName': firebaseUser.displayName ?? nick.trim(),
        'updatedAt': ServerValue.timestamp,
      });
      _currentUser = _currentUser?.copyWith(
        displayName: nick.trim(),
        nick: nick.trim(),
        avatarId: avatarId,
      );
      notifyListeners();
    } on FirebaseException catch (error) {
      _errorMessage = error.message ?? 'Nao foi possivel salvar o perfil.';
    } catch (_) {
      _errorMessage = 'Nao foi possivel salvar o perfil.';
    } finally {
      _setLoading(false);
    }
  }

  @override
  Future<void> signOut() async {
    _authSyncVersion++;
    _currentUser = null;
    _setLoading(true);
    _errorMessage = null;

    try {
      await _firebaseAuth.signOut();
      if (!kIsWeb && _enableGoogleSignIn) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {
      _errorMessage = 'Nao foi possivel sair. Tente novamente.';
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

  Future<void> _syncFirebaseUser(User? user) async {
    final syncVersion = ++_authSyncVersion;

    if (user == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    _currentUser = _mapFirebaseUser(user);
    notifyListeners();

    try {
      final profile = await _loadOrCreateUserProfile(user);
      if (syncVersion != _authSyncVersion ||
          _firebaseAuth.currentUser?.uid != user.uid) {
        return;
      }
      _currentUser = profile;
      _errorMessage = null;
      notifyListeners();
    } catch (_) {
      _errorMessage = 'Nao foi possivel carregar seu perfil salvo.';
      notifyListeners();
    }
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
      avatarId: 'star',
      photoUrl: user.photoURL,
    );
  }

  Future<AppUser> _loadOrCreateUserProfile(User user) async {
    final fallback = _mapFirebaseUser(user);
    final reference = _userReference(user.uid);
    final snapshot = await reference.get();

    if (!snapshot.exists) {
      await reference.set({
        'nick': fallback.nick,
        'avatarId': fallback.avatarId,
        'email': fallback.email,
        'displayName': fallback.displayName,
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });
      return fallback;
    }

    final rawData = snapshot.value;
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};
    return fallback.copyWith(
      nick: (data['nick'] as String?)?.trim().isNotEmpty == true
          ? (data['nick'] as String).trim()
          : fallback.nick,
      avatarId: (data['avatarId'] as String?)?.trim().isNotEmpty == true
          ? (data['avatarId'] as String).trim()
          : fallback.avatarId,
    );
  }

  DatabaseReference _userReference(String uid) {
    return _database.ref('users/$uid');
  }

  String _authErrorMessage(
    FirebaseAuthException error, {
    required String fallback,
  }) {
    return switch (error.code) {
      'operation-not-allowed' =>
        'Metodo de login desabilitado no Firebase Console.',
      'email-already-in-use' => 'Este email ja esta cadastrado.',
      'invalid-email' => 'Informe um email valido.',
      'invalid-credential' ||
      'user-not-found' ||
      'wrong-password' => 'Email ou senha invalidos.',
      'weak-password' => 'Use uma senha com pelo menos 6 caracteres.',
      'network-request-failed' => 'Verifique sua conexao e tente novamente.',
      _ => error.message ?? fallback,
    };
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
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _mockSignIn(
      id: 'mock-email-user',
      email: email.trim(),
      displayName: email.trim().split('@').first,
    );
  }

  @override
  Future<void> createAccountWithEmail({
    required String email,
    required String password,
  }) async {
    await _mockSignIn(
      id: 'mock-email-user',
      email: email.trim(),
      displayName: email.trim().split('@').first,
    );
  }

  @override
  Future<void> updateProfile({
    required String nick,
    required String avatarId,
    String? photoUrl,
  }) async {
    if (_currentUser == null) return;

    _setLoading(true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _currentUser = _currentUser!.copyWith(
      nick: nick.trim(),
      avatarId: avatarId,
      photoUrl: photoUrl,
    );
    _setLoading(false);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _mockSignIn({
    required String id,
    required String email,
    required String displayName,
  }) async {
    _setLoading(true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _currentUser = AppUser(
      id: id,
      email: email,
      displayName: displayName,
      nick: 'Novo Palpiteiro',
      avatarId: 'star',
    );
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
