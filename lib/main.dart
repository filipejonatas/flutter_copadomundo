import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'models/app_user.dart';
import 'models/leaderboard_entry.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(CopaPalpiteApp(sessionController: FirebaseSessionController()));
}

class CopaPalpiteApp extends StatelessWidget {
  const CopaPalpiteApp({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: sessionController,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Copa Palpite',
          theme: AppTheme.light(),
          home: sessionController.currentUser == null
              ? LoginScreen(sessionController: sessionController)
              : MainShell(sessionController: sessionController),
        );
      },
    );
  }
}

class AppTheme {
  static ThemeData light() {
    const green = Color(0xFF0E7C4F);
    const yellow = Color(0xFFF6C44F);
    const navy = Color(0xFF172033);

    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: green,
        primary: green,
        secondary: yellow,
        surface: const Color(0xFFF8FAF7),
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAF7),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAF7),
        foregroundColor: navy,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE1E7DF)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: Color(0xFFD4DDD2)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD4DDD2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD4DDD2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: green, width: 2),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: navy,
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: navy,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: navy,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: navy, fontSize: 16),
        bodyMedium: TextStyle(color: Color(0xFF4D596B), fontSize: 14),
      ),
    );
  }
}

final mockLeaderboard = <LeaderboardEntry>[
  const LeaderboardEntry(
    position: 1,
    nick: 'Canarinho',
    avatarId: 'cup',
    points: 128,
    exactScores: 7,
  ),
  const LeaderboardEntry(
    position: 2,
    nick: 'HexaVem',
    avatarId: 'ball',
    points: 116,
    exactScores: 5,
  ),
  const LeaderboardEntry(
    position: 3,
    nick: 'Mestre dos Palpites',
    avatarId: 'goal',
    points: 104,
    exactScores: 4,
  ),
  const LeaderboardEntry(
    position: 4,
    nick: 'Zebra Hunter',
    avatarId: 'target',
    points: 91,
    exactScores: 3,
  ),
  const LeaderboardEntry(
    position: 5,
    nick: 'VAR Amigo',
    avatarId: 'voice',
    points: 84,
    exactScores: 2,
  ),
];

LeaderboardEntry userToEntry(AppUser user) {
  return LeaderboardEntry(
    position: 6,
    nick: user.nick,
    avatarId: user.avatarId,
    points: 72,
    exactScores: 2,
    isCurrentUser: true,
  );
}
