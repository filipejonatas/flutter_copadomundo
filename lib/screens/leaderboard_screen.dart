import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';
import '../services/session_controller.dart';
import '../widgets/avatar_badge.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({
    super.key,
    required this.sessionController,
    this.leaderboardService,
  });

  final SessionController sessionController;
  final LeaderboardService? leaderboardService;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late final LeaderboardService _leaderboardService =
      widget.leaderboardService ?? LeaderboardService();
  List<LeaderboardEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userEntry = _currentUserEntry;
    final topEntries = userEntry == null
        ? _entries
        : _entries.where((entry) => entry.userId != userEntry.userId).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Ranking')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Classificacao geral', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Pontuacao consolidada apos resultado: 5 pts por placar exato e 3 pts por vencedor ou empate.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              if (userEntry != null) ...[
                Text('Sua posicao', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                _LeaderboardTile(entry: userEntry),
                const SizedBox(height: 20),
              ],
              Text('Top palpites', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              if (topEntries.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Nenhum palpite registrado ainda.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                for (final entry in topEntries) ...[
                  _LeaderboardTile(entry: entry),
                  const SizedBox(height: 10),
                ],
            ],
          ],
        ),
      ),
    );
  }

  LeaderboardEntry? get _currentUserEntry {
    final user = widget.sessionController.currentUser;
    if (user == null) return null;

    for (final entry in _entries) {
      if (entry.userId == user.id) return entry;
    }

    return null;
  }

  Future<void> _loadLeaderboard() async {
    final user = widget.sessionController.currentUser;
    if (user == null) return;

    try {
      final entries = await _leaderboardService.loadLeaderboard(user);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _entries = [_fallbackEntry(user)];
        _isLoading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nao foi possivel carregar o ranking online.'),
          ),
        );
      });
    }
  }

  LeaderboardEntry _fallbackEntry(AppUser user) {
    return LeaderboardEntry(
      position: 1,
      userId: user.id,
      nick: user.nick,
      avatarId: user.avatarId,
      points: 0,
      predictionsCount: 0,
      exactScores: 0,
      isCurrentUser: true,
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
                    '${entry.predictionsCount} palpites consolidados - ${entry.exactScores} placares exatos',
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
