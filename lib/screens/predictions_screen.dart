import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/app_user.dart';
import '../models/match_prediction.dart';
import '../services/prediction_service.dart';
import '../services/session_controller.dart';

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({
    super.key,
    required this.sessionController,
    this.predictionService,
  });

  final SessionController sessionController;
  final PredictionService? predictionService;

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  final Map<int, UserMatchPrediction> _picks = {};
  List<MatchPrediction> _matches = [];
  late final PredictionService _predictionService =
      widget.predictionService ?? PredictionService();
  bool _isLoading = true;
  int? _savingFixtureId;
  int _dayIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matchDays = _matchDays;
    final visibleDay = matchDays.isEmpty ? null : matchDays[_dayIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Palpites')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Registrar palpites', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Escolha o vencedor ou empate antes da bola rolar.',
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
              if (_matches.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Nenhum jogo encontrado.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                )
              else ...[
                Text(visibleDay!.label, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final match in visibleDay.matches) ...[
                  _PredictionCard(
                    key: ValueKey(match.fixtureId),
                    match: match,
                    selectedPrediction: _picks[match.fixtureId],
                    isSaving: _savingFixtureId == match.fixtureId,
                    onSave: (prediction) => _savePrediction(match, prediction),
                  ),
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

  Future<void> _loadPredictions() async {
    final user = widget.sessionController.currentUser;
    if (user == null) return;

    try {
      final matches = await _predictionService.loadMatches();
      final predictions = await _predictionService.loadUserPredictions(user);
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _dayIndex = 0;
        _picks
          ..clear()
          ..addAll(predictions);
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
        'Nao foi possivel conectar ao backend. Usando jogos mockados.',
      );
    }
  }

  Future<void> _savePrediction(
    MatchPrediction match,
    UserMatchPrediction prediction,
  ) async {
    final AppUser? user = widget.sessionController.currentUser;
    if (user == null) return;

    setState(() {
      _savingFixtureId = match.fixtureId;
    });

    try {
      await _predictionService.savePrediction(
        user: user,
        match: match,
        prediction: prediction,
      );
      if (!mounted) return;
      setState(() {
        _picks[match.fixtureId] = prediction;
      });
      _showMessage('Palpite salvo.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Nao foi possivel salvar o palpite.');
    } finally {
      if (mounted) {
        setState(() => _savingFixtureId = null);
      }
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

class _PredictionCard extends StatefulWidget {
  const _PredictionCard({
    super.key,
    required this.match,
    required this.selectedPrediction,
    required this.isSaving,
    required this.onSave,
  });

  final MatchPrediction match;
  final UserMatchPrediction? selectedPrediction;
  final bool isSaving;
  final ValueChanged<UserMatchPrediction> onSave;

  @override
  State<_PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends State<_PredictionCard> {
  MatchPick? _draftPick;
  late final TextEditingController _homeScoreController;
  late final TextEditingController _awayScoreController;

  @override
  void initState() {
    super.initState();
    _draftPick = widget.selectedPrediction?.pick;
    _homeScoreController = TextEditingController(
      text: _scoreText(widget.selectedPrediction?.homeScore),
    );
    _awayScoreController = TextEditingController(
      text: _scoreText(widget.selectedPrediction?.awayScore),
    );
  }

  @override
  void didUpdateWidget(covariant _PredictionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.fixtureId != widget.match.fixtureId ||
        oldWidget.selectedPrediction != widget.selectedPrediction) {
      _draftPick = widget.selectedPrediction?.pick;
      _homeScoreController.text = _scoreText(
        widget.selectedPrediction?.homeScore,
      );
      _awayScoreController.text = _scoreText(
        widget.selectedPrediction?.awayScore,
      );
    }
  }

  @override
  void dispose() {
    _homeScoreController.dispose();
    _awayScoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draftPrediction = _draftPrediction;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.match.round,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  widget.match.kickoffLabel,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${widget.match.homeTeam} x ${widget.match.awayTeam}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Status: ${widget.match.status}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Text('Placar do palpite', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _ScoreField(
                    controller: _homeScoreController,
                    label: widget.match.homeTeam,
                    enabled: !widget.isSaving,
                    onChanged: _syncPickFromScore,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ScoreField(
                    controller: _awayScoreController,
                    label: widget.match.awayTeam,
                    enabled: !widget.isSaving,
                    onChanged: _syncPickFromScore,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<MatchPick>(
              emptySelectionAllowed: true,
              segments: [
                ButtonSegment(
                  value: MatchPick.home,
                  label: Text(widget.match.homeTeam),
                  icon: const Icon(Icons.home),
                ),
                const ButtonSegment(
                  value: MatchPick.draw,
                  label: Text('Empate'),
                  icon: Icon(Icons.balance),
                ),
                ButtonSegment(
                  value: MatchPick.away,
                  label: Text(widget.match.awayTeam),
                  icon: const Icon(Icons.flight_takeoff),
                ),
              ],
              selected: _draftPick == null ? {} : {_draftPick!},
              onSelectionChanged: widget.isSaving
                  ? null
                  : (selection) {
                      setState(() {
                        _draftPick = selection.isEmpty ? null : selection.first;
                      });
                    },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: widget.isSaving || draftPrediction == null
                    ? null
                    : () => widget.onSave(draftPrediction),
                icon: const Icon(Icons.save),
                label: const Text('Salvar'),
              ),
            ),
            if (widget.selectedPrediction != null) ...[
              const SizedBox(height: 10),
              Text(
                'Salvo: ${_predictionLabel(widget.selectedPrediction!)}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
            if (widget.isSaving) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  UserMatchPrediction? get _draftPrediction {
    final homeScore = int.tryParse(_homeScoreController.text);
    final awayScore = int.tryParse(_awayScoreController.text);

    if (homeScore != null && awayScore != null) {
      return UserMatchPrediction(
        pick: pickFromScore(homeScore, awayScore),
        homeScore: homeScore,
        awayScore: awayScore,
      );
    }

    if (_draftPick == null) return null;
    return UserMatchPrediction(pick: _draftPick!);
  }

  void _syncPickFromScore(String _) {
    final homeScore = int.tryParse(_homeScoreController.text);
    final awayScore = int.tryParse(_awayScoreController.text);
    if (homeScore == null || awayScore == null) {
      setState(() {});
      return;
    }

    final scorePick = pickFromScore(homeScore, awayScore);
    setState(() => _draftPick = scorePick);
  }

  String _predictionLabel(UserMatchPrediction prediction) {
    final score = prediction.hasExactScore
        ? ' (${prediction.homeScore} x ${prediction.awayScore})'
        : '';
    return '${_pickLabel(prediction.pick)}$score';
  }

  String _scoreText(int? score) {
    return score?.toString() ?? '';
  }

  String _pickLabel(MatchPick pick) {
    return switch (pick) {
      MatchPick.home => widget.match.homeTeam,
      MatchPick.draw => 'Empate',
      MatchPick.away => widget.match.awayTeam,
    };
  }
}

class _ScoreField extends StatelessWidget {
  const _ScoreField({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, hintText: '0'),
    );
  }
}
