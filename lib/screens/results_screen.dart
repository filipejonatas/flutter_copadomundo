import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/match_prediction.dart';
import '../services/prediction_service.dart';
import '../theme/app_theme.dart';
import '../widgets/match_card.dart';

/// Matches screen showing official scores and status cards by date.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, this.predictionService});

  final PredictionService? predictionService;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  List<MatchPrediction> _matches = [];
  late final PredictionService _predictionService =
      widget.predictionService ?? PredictionService();
  bool _isLoading = true;
  int _dayIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadResults();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchDays = _matchDays;
    final visibleDay = matchDays.isEmpty ? null : matchDays[_dayIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
          children: [
            Text('Calendario oficial', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Placares e status da fase de grupos em tempo real.',
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
            else if (_matches.isEmpty)
              const _SurfaceMessage(message: 'Nenhum resultado encontrado.')
            else ...[
              Text(visibleDay!.label, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final match in visibleDay.matches)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MatchCard(match: match)
                      .animate()
                      .fadeIn(duration: 220.ms)
                      .slideY(begin: .06, end: 0),
                ),
              if (matchDays.length > 1)
                _MatchDaysPager(
                  currentDay: _dayIndex + 1,
                  totalDays: matchDays.length,
                  onPrevious: _dayIndex == 0
                      ? null
                      : () => setState(() => _dayIndex--),
                  onNext: _dayIndex >= matchDays.length - 1
                      ? null
                      : () => setState(() => _dayIndex++),
                ),
            ],
          ],
        ),
      ),
    );
  }

  List<_MatchDay> get _matchDays {
    final days = <String, List<MatchPrediction>>{};
    for (final match in _matches) {
      days.putIfAbsent(_dayLabel(match), () => []).add(match);
    }

    return days.entries
        .map((entry) => _MatchDay(label: entry.key, matches: entry.value))
        .toList();
  }

  Future<void> _loadResults() async {
    try {
      final matches = await _predictionService.loadMatches();
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _dayIndex = 0;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _matches = mockMatches;
        _dayIndex = 0;
        _isLoading = false;
      });
      _showMessage(
        'Nao foi possivel conectar ao backend. Usando resultados mockados.',
      );
    }
  }

  String _dayLabel(MatchPrediction match) {
    final labelParts = match.kickoffLabel.split(',');
    if (labelParts.isEmpty) return 'Dia do jogo';
    return labelParts.first.trim();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _MatchDay {
  const _MatchDay({required this.label, required this.matches});

  final String label;
  final List<MatchPrediction> matches;
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
