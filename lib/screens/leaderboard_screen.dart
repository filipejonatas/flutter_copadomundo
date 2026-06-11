import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/app_user.dart';
import '../models/leaderboard_entry.dart';
import '../services/leaderboard_service.dart';
import '../services/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/logout_circle_button.dart';

/// Ranking screen with leaderboard positions, avatars, and points badges.
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
      appBar: AppBar(
        title: const Text('Ranking'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LogoutCircleButton(
              sessionController: widget.sessionController,
            ),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
          children: [
            Text('Leaderboard', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              '5 pts por placar exato. 3 pts por vencedor ou empate.',
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
                LeaderboardTile(entry: userEntry),
                const SizedBox(height: 20),
              ],
              Text('Top palpites', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              if (topEntries.isEmpty)
                const _SurfaceMessage(
                  message: 'Nenhum palpite registrado ainda.',
                )
              else
                for (final entry in topEntries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: LeaderboardTile(
                      entry: entry,
                    ).animate().fadeIn(duration: 220.ms).slideY(begin: .04),
                  ),
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
      photoUrl: user.photoUrl,
      points: 0,
      predictionsCount: 0,
      exactScores: 0,
      isCurrentUser: true,
    );
  }
}

/// A reusable leaderboard row with position, avatar, username, and points.
class LeaderboardTile extends StatelessWidget {
  const LeaderboardTile({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highlight = entry.isCurrentUser
        ? AppColors.primaryAccent.withValues(alpha: .1)
        : AppColors.surface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: entry.isCurrentUser
              ? AppColors.primaryAccent.withValues(alpha: .3)
              : Colors.white.withValues(alpha: .06),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Row(
              children: [
                if (entry.position <= 3) ...[
                  Tooltip(
                    message: 'Top 3',
                    child: PhosphorIcon(
                      PhosphorIcons.trophy(PhosphorIconsStyle.fill),
                      size: 14,
                      color: AppColors.primaryAccent,
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  '#${entry.position}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: entry.position <= 3
                        ? AppColors.primaryAccent
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          AvatarBadge(avatarId: entry.avatarId, photoUrl: entry.photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.nick, style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.target(),
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${entry.predictionsCount} palpites - ${entry.exactScores} exatos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryAccent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              '${entry.points} pts',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceMessage extends StatelessWidget {
  const _SurfaceMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
