import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'firebase_options.dart';
import 'models/app_user.dart';
import 'models/leaderboard_entry.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/home_screen.dart';
import 'screens/leaderboard_screen.dart';
import 'screens/predictions_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_page.dart';
import 'theme/app_theme.dart';
import 'services/app_check_config.dart';
import 'services/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: FirebaseBootstrapApp()));
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) return;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') rethrow;
  }
}

class FirebaseBootstrapApp extends StatefulWidget {
  const FirebaseBootstrapApp({super.key});

  @override
  State<FirebaseBootstrapApp> createState() => _FirebaseBootstrapAppState();
}

class _FirebaseBootstrapAppState extends State<FirebaseBootstrapApp> {
  late final Future<FirebaseSessionController> _bootstrapFuture = _bootstrap();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseSessionController>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        final controller = snapshot.data;
        if (controller != null) {
          return CopaPalpiteApp(sessionController: controller);
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Copa Palpite',
          theme: AppTheme.dark(),
          home: SplashPage(
            isBusy: true,
            errorMessage: snapshot.hasError
                ? 'Nao foi possivel iniciar o app. Tente recarregar.'
                : null,
          ),
        );
      },
    );
  }

  Future<FirebaseSessionController> _bootstrap() async {
    await _initializeFirebase();
    await activateAppCheck();
    return FirebaseSessionController();
  }
}

/// Root app widget that wires theme, session redirects, and navigation.
class CopaPalpiteApp extends StatelessWidget {
  const CopaPalpiteApp({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: sessionController,
      redirect: (context, state) {
        final signedIn = sessionController.currentUser != null;
        final atSplash = state.matchedLocation == '/splash';
        final atLogin = state.matchedLocation == '/login';
        if (atSplash) return null;
        if (!signedIn) return atLogin ? null : '/login';
        if (atLogin) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              LoginPage(sessionController: sessionController),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => MainShell(
            sessionController: sessionController,
            navigationShell: navigationShell,
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) =>
                      HomeScreen(sessionController: sessionController),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/matches',
                  builder: (context, state) =>
                      PredictionsScreen(sessionController: sessionController),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/ranking',
                  builder: (context, state) =>
                      LeaderboardScreen(sessionController: sessionController),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/profile',
                  builder: (context, state) =>
                      ProfileScreen(sessionController: sessionController),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Copa Palpite',
      theme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}

final mockLeaderboard = <LeaderboardEntry>[
  const LeaderboardEntry(
    position: 1,
    userId: 'mock-canarinho',
    nick: 'Canarinho',
    avatarId: 'cup',
    points: 128,
    predictionsCount: 24,
    exactScores: 7,
  ),
  const LeaderboardEntry(
    position: 2,
    userId: 'mock-hexa-vem',
    nick: 'HexaVem',
    avatarId: 'ball',
    points: 116,
    predictionsCount: 22,
    exactScores: 5,
  ),
  const LeaderboardEntry(
    position: 3,
    userId: 'mock-mestre',
    nick: 'Mestre dos Palpites',
    avatarId: 'goal',
    points: 104,
    predictionsCount: 20,
    exactScores: 4,
  ),
  const LeaderboardEntry(
    position: 4,
    userId: 'mock-zebra',
    nick: 'Zebra Hunter',
    avatarId: 'target',
    points: 91,
    predictionsCount: 18,
    exactScores: 3,
  ),
  const LeaderboardEntry(
    position: 5,
    userId: 'mock-var',
    nick: 'VAR Amigo',
    avatarId: 'voice',
    points: 84,
    predictionsCount: 16,
    exactScores: 2,
  ),
];

LeaderboardEntry userToEntry(AppUser user) {
  return LeaderboardEntry(
    position: 6,
    userId: user.id,
    nick: user.nick,
    avatarId: user.avatarId,
    points: 72,
    predictionsCount: 14,
    exactScores: 2,
    isCurrentUser: true,
  );
}
