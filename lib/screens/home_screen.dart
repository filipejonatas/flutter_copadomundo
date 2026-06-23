import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/match_prediction.dart';
import '../services/prediction_service.dart';
import '../services/session_controller.dart';
import '../theme/app_theme.dart';
import '../utils/match_day_selector.dart';
import '../widgets/logout_circle_button.dart';
import '../widgets/match_card.dart';

/// Home screen with group stage matches grouped by match date.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.sessionController,
    this.predictionService,
  });

  final SessionController sessionController;
  final PredictionService? predictionService;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MatchPrediction> _matches = [];
  late final PredictionService _predictionService =
      widget.predictionService ?? PredictionService();
  bool _isLoading = true;
  int _dayIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = _matchGroups;
    final visibleGroup = groups.isEmpty ? null : groups[_dayIndex];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.primaryAccent,
          backgroundColor: AppColors.surface,
          onRefresh: _loadMatches,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bolao 2026', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Fase de grupos',
                          style: theme.textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  LogoutCircleButton(
                    sessionController: widget.sessionController,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _CompetitionStrip(matchCount: _matches.length),
              const SizedBox(height: 22),
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (groups.isEmpty)
                const _EmptyState(message: 'Nenhum jogo encontrado.')
              else ...[
                _GroupHeader(label: visibleGroup!.label),
                const SizedBox(height: 12),
                for (final match in visibleGroup.matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child:
                        MatchCard(
                              match: match,
                              footer: _MatchMeta(match: match),
                            )
                            .animate()
                            .fadeIn(duration: 250.ms)
                            .slideY(begin: .08, end: 0, duration: 250.ms),
                  ),
                if (groups.length > 1)
                  _MatchDaysPager(
                    currentDay: _dayIndex + 1,
                    totalDays: groups.length,
                    onPrevious: _dayIndex == 0
                        ? null
                        : () => setState(() => _dayIndex--),
                    onNext: _dayIndex >= groups.length - 1
                        ? null
                        : () => setState(() => _dayIndex++),
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<_MatchGroup> get _matchGroups {
    return _buildMatchGroups(_matches);
  }

  List<_MatchGroup> _buildMatchGroups(List<MatchPrediction> matches) {
    final groups = <String, List<MatchPrediction>>{};
    for (final match in matches) {
      groups.putIfAbsent(_dayLabel(match), () => []).add(match);
    }

    return groups.entries
        .map((entry) => _MatchGroup(label: entry.key, matches: entry.value))
        .toList();
  }

  Future<void> _loadMatches() async {
    setState(() => _isLoading = true);
    try {
      final matches = await _predictionService.loadMatches();
      if (!mounted) return;
      final groups = _buildMatchGroups(matches);
      setState(() {
        _matches = matches;
        _dayIndex = initialMatchDayIndex(
          groups.map((group) => group.matches).toList(),
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (kReleaseMode) {
        setState(() {
          _matches = [];
          _dayIndex = 0;
          _isLoading = false;
        });
        return;
      }
      final groups = _buildMatchGroups(mockMatches);
      setState(() {
        _matches = mockMatches;
        _dayIndex = initialMatchDayIndex(
          groups.map((group) => group.matches).toList(),
        );
        _isLoading = false;
      });
    }
  }

  String _dayLabel(MatchPrediction match) {
    final labelParts = match.kickoffLabel.split(',');
    if (labelParts.isEmpty) return 'Dia do jogo';
    return labelParts.first.trim();
  }
}

class _MatchGroup {
  const _MatchGroup({required this.label, required this.matches});

  final String label;
  final List<MatchPrediction> matches;
}

class _CompetitionStrip extends StatelessWidget {
  const _CompetitionStrip({required this.matchCount});

  final int matchCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: AppColors.primaryAccent.withValues(alpha: .2),
        ),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            PhosphorIcons.trophy(PhosphorIconsStyle.fill),
            color: AppColors.primaryAccent,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'FIFA World Cup 2026 - Group Stage',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Text(
            '$matchCount jogos',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: .08))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: .08))),
      ],
    );
  }
}

class _MatchMeta extends StatelessWidget {
  const _MatchMeta({required this.match});

  final MatchPrediction match;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PhosphorIcon(
          PhosphorIcons.clock(),
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            match.kickoffLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Text(match.round, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _MatchDaysPager extends StatelessWidget {
  const _MatchDaysPager({
    required this.currentDay,
    required this.totalDays,
    required this.onPrevious,
    required this.onNext,
  });

  final int currentDay;
  final int totalDays;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Dia anterior',
            onPressed: onPrevious,
            icon: PhosphorIcon(PhosphorIcons.caretLeft()),
          ),
          Expanded(
            child: Text(
              'Dia $currentDay de $totalDays',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Proximo dia',
            onPressed: onNext,
            icon: PhosphorIcon(PhosphorIcons.caretRight()),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
