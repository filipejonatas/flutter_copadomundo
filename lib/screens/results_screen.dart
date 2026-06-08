import 'package:flutter/material.dart';

import '../models/match_prediction.dart';
import '../services/prediction_service.dart';

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
      appBar: AppBar(title: const Text('Resultados')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Resultados dos jogos', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Acompanhe os placares oficiais partida por partida.',
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Nenhum resultado encontrado.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else ...[
              Text(visibleDay!.label, style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              for (final match in visibleDay.matches) ...[
                _ResultCard(match: match),
                const SizedBox(height: 12),
              ],
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
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Dia anterior',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                'Dia $currentDay de $totalDays',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Proximo dia',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.match});

  final MatchPrediction match;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(match.round, style: theme.textTheme.titleMedium),
                ),
                Text(match.kickoffLabel, style: theme.textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.homeTeam,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _ScoreBox(score: match.homeScore),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    match.awayTeam,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                _ScoreBox(score: match.awayScore),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              match.hasResult
                  ? 'Resultado final'
                  : 'Resultado pendente - status: ${match.status}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({required this.score});

  final int? score;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 44,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Text(score?.toString() ?? '-', style: theme.textTheme.titleLarge),
    );
  }
}
