import 'package:flutter/material.dart';

import '../main.dart';
import '../models/leaderboard_entry.dart';
import '../services/session_controller.dart';
import '../widgets/avatar_badge.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key, required this.sessionController});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    final user = sessionController.currentUser!;
    final userEntry = userToEntry(user);
    final entries = [...mockLeaderboard, userEntry];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Classificacao geral', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Ranking mockado para validar o fluxo antes de conectar resultados oficiais da API externa.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text('Sua posicao', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _LeaderboardTile(entry: userEntry),
            const SizedBox(height: 20),
            Text('Top palpites', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final entry in entries) ...[
              _LeaderboardTile(entry: entry),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaderboardTile extends StatelessWidget {
  const _LeaderboardTile({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlightColor = theme.colorScheme.primary.withValues(alpha: .08);

    return Card(
      color: entry.isCurrentUser ? highlightColor : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '#${entry.position}',
                style: theme.textTheme.titleMedium,
              ),
            ),
            AvatarBadge(avatarId: entry.avatarId),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.nick, style: theme.textTheme.titleMedium),
                  Text(
                    '${entry.exactScores} placares exatos',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Text(
              '${entry.points} pts',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
