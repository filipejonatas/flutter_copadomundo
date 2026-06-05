import 'package:flutter/material.dart';

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
  final Map<int, MatchPick> _picks = {};
  List<MatchPrediction> _matches = [];
  late final PredictionService _predictionService =
      widget.predictionService ?? PredictionService();
  bool _isLoading = true;
  int? _savingFixtureId;

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            else
              for (final match in _matches) ...[
                _PredictionCard(
                  key: ValueKey(match.fixtureId),
                  match: match,
                  selectedPick: _picks[match.fixtureId],
                  isSaving: _savingFixtureId == match.fixtureId,
                  onSave: (pick) => _savePrediction(match, pick),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
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
        _picks
          ..clear()
          ..addAll(predictions);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _matches = mockMatches;
        _isLoading = false;
      });
      _showMessage(
        'Nao foi possivel conectar ao backend. Usando jogos mockados.',
      );
    }
  }

  Future<void> _savePrediction(MatchPrediction match, MatchPick pick) async {
    final AppUser? user = widget.sessionController.currentUser;
    if (user == null) return;

    setState(() {
      _savingFixtureId = match.fixtureId;
    });

    try {
      await _predictionService.savePrediction(
        user: user,
        match: match,
        pick: pick,
      );
      if (!mounted) return;
      setState(() {
        _picks[match.fixtureId] = pick;
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _PredictionCard extends StatefulWidget {
  const _PredictionCard({
    super.key,
    required this.match,
    required this.selectedPick,
    required this.isSaving,
    required this.onSave,
  });

  final MatchPrediction match;
  final MatchPick? selectedPick;
  final bool isSaving;
  final ValueChanged<MatchPick> onSave;

  @override
  State<_PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends State<_PredictionCard> {
  MatchPick? _draftPick;

  @override
  void initState() {
    super.initState();
    _draftPick = widget.selectedPick;
  }

  @override
  void didUpdateWidget(covariant _PredictionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.fixtureId != widget.match.fixtureId ||
        oldWidget.selectedPick != widget.selectedPick) {
      _draftPick = widget.selectedPick;
    }
  }

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
                onPressed: widget.isSaving || _draftPick == null
                    ? null
                    : () => widget.onSave(_draftPick!),
                icon: const Icon(Icons.save),
                label: const Text('Salvar'),
              ),
            ),
            if (widget.selectedPick != null) ...[
              const SizedBox(height: 10),
              Text(
                'Salvo: ${_pickLabel(widget.selectedPick!)}',
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

  String _pickLabel(MatchPick pick) {
    return switch (pick) {
      MatchPick.home => widget.match.homeTeam,
      MatchPick.draw => 'Empate',
      MatchPick.away => widget.match.awayTeam,
    };
  }
}
