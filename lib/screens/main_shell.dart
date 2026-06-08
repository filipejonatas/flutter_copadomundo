import 'package:flutter/material.dart';

import '../services/session_controller.dart';
import 'leaderboard_screen.dart';
import 'predictions_screen.dart';
import 'profile_screen.dart';
import 'results_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProfileScreen(sessionController: widget.sessionController),
      PredictionsScreen(sessionController: widget.sessionController),
      const ResultsScreen(),
      LeaderboardScreen(sessionController: widget.sessionController),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Palpites',
          ),
          NavigationDestination(
            icon: Icon(Icons.sports_soccer_outlined),
            selectedIcon: Icon(Icons.sports_soccer),
            label: 'Resultados',
          ),
          NavigationDestination(
            icon: Icon(Icons.leaderboard_outlined),
            selectedIcon: Icon(Icons.leaderboard),
            label: 'Ranking',
          ),
        ],
      ),
    );
  }
}
