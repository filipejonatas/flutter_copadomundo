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
              'Escolha vencedor ou empate antes da bola rolar.',
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
                  match: match,
                  selectedPick: _picks[match.fixtureId],
                  isSaving: _savingFixtureId == match.fixtureId,
                  onPickSelected: (pick) => _savePrediction(match, pick),
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
      _picks[match.fixtureId] = pick;
    });

    try {
      await _predictionService.savePrediction(
        user: user,
        match: match,
        pick: pick,
      );
      if (!mounted) return;
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

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({
    required this.match,
    required this.selectedPick,
    required this.isSaving,
    required this.onPickSelected,
  });

  final MatchPrediction match;
  final MatchPick? selectedPick;
  final bool isSaving;
  final ValueChanged<MatchPick> onPickSelected;

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
            const SizedBox(height: 12),
            Text(
              '${match.homeTeam} x ${match.awayTeam}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Status API-Football: ${match.status}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            SegmentedButton<MatchPick>(
              segments: [
                ButtonSegment(
                  value: MatchPick.home,
                  label: Text(match.homeTeam),
                  icon: const Icon(Icons.home),
                ),
                const ButtonSegment(
                  value: MatchPick.draw,
                  label: Text('Empate'),
                  icon: Icon(Icons.balance),
                ),
                ButtonSegment(
                  value: MatchPick.away,
                  label: Text(match.awayTeam),
                  icon: const Icon(Icons.flight_takeoff),
                ),
              ],
              selected: selectedPick == null ? {} : {selectedPick!},
              onSelectionChanged: isSaving
                  ? null
                  : (selection) => onPickSelected(selection.first),
            ),
            if (isSaving) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
