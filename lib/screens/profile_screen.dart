import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/app_user.dart';
import '../models/avatar_option.dart';
import '../models/leaderboard_entry.dart';
import '../models/match_prediction.dart';
import '../services/leaderboard_service.dart';
import '../services/prediction_service.dart';
import '../services/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_badge.dart';
import '../widgets/logout_circle_button.dart';

/// Profile screen with avatar, editable identity, stats, and history.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.sessionController,
    this.leaderboardService,
    this.predictionService,
  });

  final SessionController sessionController;
  final LeaderboardService? leaderboardService;
  final PredictionService? predictionService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nickController;
  LeaderboardEntry? _userStats;
  List<_PredictionHistoryItem> _history = [];
  bool _isStatsLoading = true;
  String? _statsError;
  late String _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    final user = widget.sessionController.currentUser!;
    _nickController = TextEditingController(text: user.nick);
    _selectedAvatarId = user.avatarId;
    _loadProfileStats(user);
  }

  @override
  void dispose() {
    _nickController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.sessionController.currentUser!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
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
            _UserSummary(user: user),
            const SizedBox(height: 16),
            _StatsGrid(entry: _userStats, isLoading: _isStatsLoading),
            if (_statsError != null) ...[
              const SizedBox(height: 10),
              _SurfaceMessage(message: _statsError!),
            ],
            const SizedBox(height: 22),
            Text('Nick no ranking', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _nickController,
              maxLength: 24,
              decoration: const InputDecoration(
                hintText: 'Como voce quer aparecer?',
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            Text('Avatar', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: avatarOptions.map((avatar) {
                final isSelected = avatar.id == _selectedAvatarId;
                return ChoiceChip(
                  selected: isSelected,
                  onSelected: (_) =>
                      setState(() => _selectedAvatarId = avatar.id),
                  label: PhosphorIcon(
                    avatar.icon,
                    color: avatar.color,
                    size: 26,
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.all(10),
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primaryAccent.withValues(alpha: .14),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primaryAccent
                        : Colors.white.withValues(alpha: .08),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: widget.sessionController.isLoading ? null : _save,
              icon: widget.sessionController.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : PhosphorIcon(PhosphorIcons.floppyDisk()),
              label: Text(
                widget.sessionController.isLoading
                    ? 'Salvando...'
                    : 'Salvar perfil',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.sessionController.isLoading
                  ? null
                  : widget.sessionController.signOut,
              icon: PhosphorIcon(PhosphorIcons.signOut()),
              label: const Text('Sair'),
            ),
            const SizedBox(height: 24),
            Text('Historico', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            if (_isStatsLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_history.isEmpty)
              const _SurfaceMessage(
                message: 'Nenhum palpite registrado no backend ainda.',
              )
            else
              for (final item in _history) ...[
                _HistoryTile(item: item),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final nick = _nickController.text.trim();
    if (nick.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use um nick com pelo menos 3 letras.')),
      );
      return;
    }

    await widget.sessionController.updateProfile(
      nick: nick,
      avatarId: _selectedAvatarId,
    );

    if (!mounted) return;
    if (widget.sessionController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.sessionController.errorMessage!)),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
    setState(() {});
    await _loadProfileStats(widget.sessionController.currentUser!);
  }

  Future<void> _loadProfileStats(AppUser user) async {
    setState(() {
      _isStatsLoading = true;
      _statsError = null;
    });

    try {
      final leaderboardService =
          widget.leaderboardService ?? LeaderboardService();
      final predictionService = widget.predictionService ?? PredictionService();
      final results = await Future.wait<Object>([
        leaderboardService.loadLeaderboard(user),
        predictionService.loadMatches(),
        predictionService.loadUserPredictions(user),
      ]);

      if (!mounted) return;
      final leaderboard = results[0] as List<LeaderboardEntry>;
      final matches = results[1] as List<MatchPrediction>;
      final predictions = results[2] as Map<int, UserMatchPrediction>;
      LeaderboardEntry? userEntry;
      for (final entry in leaderboard) {
        if (entry.userId == user.id) {
          userEntry = entry;
          break;
        }
      }
      final matchesById = {for (final match in matches) match.fixtureId: match};

      setState(() {
        _userStats = userEntry;
        _history = predictions.entries
            .map((entry) {
              final match = matchesById[entry.key];
              if (match == null) return null;
              return _PredictionHistoryItem(
                match: match,
                prediction: entry.value,
              );
            })
            .nonNulls
            .toList()
            .reversed
            .toList();
        _isStatsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStatsLoading = false;
        _statsError =
            'Nao foi possivel carregar estatisticas reais do backend.';
        _history = [];
      });
    }
  }
}

class _UserSummary extends StatelessWidget {
  const _UserSummary({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          AvatarBadge(avatarId: user.avatarId, radius: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.nick, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.entry, required this.isLoading});

  final LeaderboardEntry? entry;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final points = isLoading ? '--' : '${entry?.points ?? 0}';
    final exactScores = isLoading ? '--' : '${entry?.exactScores ?? 0}';
    final predictions = isLoading ? '--' : '${entry?.predictionsCount ?? 0}';
    final position = isLoading ? '--' : '#${entry?.position ?? 0}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 520;
        return GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: isWide ? 1.7 : 1.45,
          children: [
            _StatCard(label: 'Pontos', value: points),
            _StatCard(label: 'Exatos', value: exactScores),
            _StatCard(label: 'Palpites', value: predictions),
            _StatCard(label: 'Posicao', value: position),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.primaryAccent),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item});

  final _PredictionHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            PhosphorIcons.clockCounterClockwise(),
            color: AppColors.secondaryAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get title => '${item.match.homeTeam} x ${item.match.awayTeam}';
}

class _PredictionHistoryItem {
  const _PredictionHistoryItem({required this.match, required this.prediction});

  final MatchPrediction match;
  final UserMatchPrediction prediction;

  String get subtitle {
    final home = prediction.homeScore ?? '-';
    final away = prediction.awayScore ?? '-';
    return 'Palpite: $home x $away - ${_pickLabel(prediction.pick)}';
  }

  String _pickLabel(MatchPick pick) {
    return switch (pick) {
      MatchPick.home => match.homeTeam,
      MatchPick.draw => 'Empate',
      MatchPick.away => match.awayTeam,
    };
  }
}

class _SurfaceMessage extends StatelessWidget {
  const _SurfaceMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
