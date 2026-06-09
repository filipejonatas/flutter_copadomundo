import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../services/session_controller.dart';
import '../theme/app_theme.dart';

final _loginNotifierProvider = ChangeNotifierProvider.autoDispose
    .family<LoginNotifier, SessionController>(
      (ref, sessionController) => LoginNotifier(sessionController),
    );

enum LoginAction { google, email }

/// Riverpod notifier that coordinates sign-in UI state.
class LoginNotifier extends ChangeNotifier {
  LoginNotifier(this._sessionController);

  final SessionController _sessionController;
  bool _isLoading = false;
  LoginAction? _loadingAction;
  String? _error;

  bool get isLoading => _isLoading;
  LoginAction? get loadingAction => _loadingAction;
  String? get error => _error;

  Future<bool> signInWithGoogle() {
    return _run(LoginAction.google, _sessionController.signInWithGoogle);
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
    required bool createAccount,
  }) {
    return _run(
      LoginAction.email,
      () => createAccount
          ? _sessionController.createAccountWithEmail(
              email: email,
              password: password,
            )
          : _sessionController.signInWithEmail(
              email: email,
              password: password,
            ),
    );
  }

  Future<bool> _run(LoginAction action, Future<void> Function() task) async {
    _setLoading(action);
    _error = null;

    try {
      await task();
      for (var attempt = 0; attempt < 12; attempt++) {
        if (_sessionController.currentUser != null) return true;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      _error =
          _sessionController.errorMessage ??
          'Erro ao fazer login. Tente novamente.';
      return false;
    } catch (_) {
      _error =
          _sessionController.errorMessage ??
          'Erro ao fazer login. Tente novamente.';
      return false;
    } finally {
      _clearLoading();
    }
  }

  void _setLoading(LoginAction action) {
    _isLoading = true;
    _loadingAction = action;
    notifyListeners();
  }

  void _clearLoading() {
    _isLoading = false;
    _loadingAction = null;
    notifyListeners();
  }
}

/// Login page with Google, Apple, and email/password authentication.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _createAccount = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(
      _loginNotifierProvider(widget.sessionController),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: true,
        bottom: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxHeight < 720;
            final bottomCard =
                _LoginBottomCard(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      createAccount: _createAccount,
                      notifier: notifier,
                      onCreateAccountChanged: (value) =>
                          setState(() => _createAccount = value),
                      onGoogleSignIn: () => _signInWithGoogle(notifier),
                      onEmailSignIn: () => _signInWithEmail(notifier),
                    )
                    .animate()
                    .slideY(
                      begin: .3,
                      end: 0,
                      delay: 200.ms,
                      duration: 400.ms,
                      curve: Curves.easeOutCubic,
                    )
                    .fadeIn(delay: 200.ms, duration: 400.ms);

            if (isCompact) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 24, 24, 18),
                        child: _LoginHero(),
                      ),
                      bottomCard,
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                const Expanded(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24),
                      child: _LoginHero(),
                    ),
                  ),
                ),
                bottomCard,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle(LoginNotifier notifier) async {
    await _handleSignIn(notifier.signInWithGoogle());
  }

  Future<void> _signInWithEmail(LoginNotifier notifier) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      _showLoginError('Informe email e senha com pelo menos 6 caracteres.');
      return;
    }

    await _handleSignIn(
      notifier.signInWithEmail(
        email: email,
        password: password,
        createAccount: _createAccount,
      ),
    );
  }

  Future<void> _handleSignIn(Future<bool> signInTask) async {
    final success = await signInTask;
    if (!mounted) return;

    if (success) {
      context.go('/home');
      return;
    }

    final notifier = ref.read(_loginNotifierProvider(widget.sessionController));
    _showLoginError(notifier.error ?? 'Erro ao fazer login. Tente novamente.');
  }

  void _showLoginError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: AppColors.liveBadge, content: Text(message)),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFD700).withValues(alpha: .25),
                blurRadius: 30,
                spreadRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset(
              'assets/images/trophy_icon.png',
              width: 140,
              height: 140,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Copa Palpite',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Entre para fazer seus palpites',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _LoginBottomCard extends StatelessWidget {
  const _LoginBottomCard({
    required this.emailController,
    required this.passwordController,
    required this.createAccount,
    required this.notifier,
    required this.onCreateAccountChanged,
    required this.onGoogleSignIn,
    required this.onEmailSignIn,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool createAccount;
  final LoginNotifier notifier;
  final ValueChanged<bool> onCreateAccountChanged;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onEmailSignIn;

  @override
  Widget build(BuildContext context) {
    final isLoading = notifier.isLoading;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Bem-vindo',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Acesse sua conta para registrar e acompanhar seus palpites.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            _GoogleSignInButton(
              isLoading:
                  isLoading && notifier.loadingAction == LoginAction.google,
              onPressed: isLoading ? null : onGoogleSignIn,
            ).animate().fadeIn(delay: 500.ms, duration: 350.ms),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: .08)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'ou',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.white.withValues(alpha: .08)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              enabled: !isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(hintText: 'Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              enabled: !isLoading,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(hintText: 'Senha'),
              onSubmitted: (_) {
                if (!isLoading) onEmailSignIn();
              },
            ),
            const SizedBox(height: 10),
            SwitchListTile.adaptive(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: createAccount,
              activeThumbColor: AppColors.primaryAccent,
              title: const Text(
                'Criar nova conta',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
              onChanged: isLoading ? null : onCreateAccountChanged,
            ),
            const SizedBox(height: 10),
            _EmailSignInButton(
              label: createAccount ? 'Criar conta' : 'Entrar com email',
              isLoading:
                  isLoading && notifier.loadingAction == LoginAction.email,
              onPressed: isLoading ? null : onEmailSignIn,
            ),
            const SizedBox(height: 16),
            const _TermsText(),
          ],
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _AuthButton(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      borderColor: const Color(0xFF2A2A2A),
      isLoading: isLoading,
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/images/google_logo.svg',
            width: 22,
            height: 22,
          ),
          const SizedBox(width: 12),
          const Text(
            'Continuar com o Google',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailSignInButton extends StatelessWidget {
  const _EmailSignInButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _AuthButton(
      backgroundColor: AppColors.primaryAccent,
      foregroundColor: Colors.black,
      borderColor: AppColors.primaryAccent,
      isLoading: isLoading,
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.isLoading,
    required this.onPressed,
    required this.child,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.pill),
          onTap: onPressed,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(color: borderColor),
            ),
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foregroundColor,
                    ),
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

class _TermsText extends StatelessWidget {
  const _TermsText();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: 'Ao continuar, você aceita nossos ',
        style: const TextStyle(color: Color(0xFF555555), fontSize: 11),
        children: [
          TextSpan(
            text: 'Termos de Uso',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
            recognizer: TapGestureRecognizer()..onTap = () {},
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
