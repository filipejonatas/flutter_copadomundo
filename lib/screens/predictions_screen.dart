import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/app_user.dart';
import '../models/match_prediction.dart';
import '../services/prediction_service.dart';
import '../services/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/logout_circle_button.dart';
import '../widgets/match_card.dart';

/// Palpite screen where users predict exact scores for each match.
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
      appBar: AppBar(
        title: const Text('Matches'),
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
            Text('Seus palpites', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Ajuste o placar de 0 a 9 antes da bola rolar.',
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
                const _SurfaceMessage(message: 'Nenhum jogo encontrado.')
              else ...[
                Text(visibleDay!.label, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final match in visibleDay.matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PredictionCard(
                      key: ValueKey(match.fixtureId),
                      match: match,
                      selectedPrediction: _picks[match.fixtureId],
                      isSaving: _savingFixtureId == match.fixtureId,
                      isLocked: !match.isPredictionOpen(),
                      onSave: (prediction) =>
                          _savePrediction(match, prediction),
                    ).animate().fadeIn(duration: 220.ms).slideY(begin: .06),
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
      if (kReleaseMode) {
        setState(() {
          _matches = [];
          _dayIndex = 0;
          _isLoading = false;
        });
        _showMessage('Nao foi possivel conectar ao backend.');
        return;
      }
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

class _PredictionCard extends StatefulWidget {
  const _PredictionCard({
    super.key,
    required this.match,
    required this.selectedPrediction,
    required this.isSaving,
    required this.isLocked,
    required this.onSave,
  });

  final MatchPrediction match;
  final UserMatchPrediction? selectedPrediction;
  final bool isSaving;
  final bool isLocked;
  final ValueChanged<UserMatchPrediction> onSave;

  @override
  State<_PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends State<_PredictionCard> {
  late int _homeScore;
  late int _awayScore;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant _PredictionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.fixtureId != widget.match.fixtureId ||
        oldWidget.selectedPrediction != widget.selectedPrediction) {
      _syncFromWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prediction = _draftPrediction;

    return MatchCard(
      match: widget.match,
      homeScoreOverride: _homeScore,
      awayScoreOverride: _awayScore,
      footer: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ScoreStepper(
                  label: widget.match.homeTeam,
                  value: _homeScore,
                  enabled: !widget.isSaving && !widget.isLocked,
                  onChanged: (value) => setState(() => _homeScore = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScoreStepper(
                  label: widget.match.awayTeam,
                  value: _awayScore,
                  enabled: !widget.isSaving && !widget.isLocked,
                  onChanged: (value) => setState(() => _awayScore = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: widget.isSaving || widget.isLocked
                ? null
                : () => widget.onSave(prediction),
            icon: widget.isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PhosphorIcon(PhosphorIcons.checkCircle()),
            label: Text(
              widget.isSaving ? 'Confirmando...' : 'Confirmar palpite',
            ),
          ),
          if (widget.isLocked) ...[
            const SizedBox(height: 10),
            Text(
              'Palpites encerrados para este jogo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (widget.selectedPrediction != null) ...[
            const SizedBox(height: 10),
            Text(
              'Salvo: ${_predictionLabel(widget.selectedPrediction!)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }

  UserMatchPrediction get _draftPrediction {
    return UserMatchPrediction(
      pick: pickFromScore(_homeScore, _awayScore),
      homeScore: _homeScore,
      awayScore: _awayScore,
    );
  }

  void _syncFromWidget() {
    _homeScore = widget.selectedPrediction?.homeScore ?? 0;
    _awayScore = widget.selectedPrediction?.awayScore ?? 0;
  }

  String _predictionLabel(UserMatchPrediction prediction) {
    return '${_pickLabel(prediction.pick)} (${prediction.homeScore} x ${prediction.awayScore})';
  }

  String _pickLabel(MatchPick pick) {
    return switch (pick) {
      MatchPick.home => widget.match.homeTeam,
      MatchPick.draw => 'Empate',
      MatchPick.away => widget.match.awayTeam,
    };
  }
}

class _ScoreStepper extends StatelessWidget {
  const _ScoreStepper({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(
                tooltip: 'Diminuir',
                icon: PhosphorIcons.minus(),
                enabled: enabled && value > 0,
                onTap: () => onChanged(value - 1),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 28),
                ),
              ),
              _StepButton(
                tooltip: 'Aumentar',
                icon: PhosphorIcons.plus(),
                enabled: enabled && value < 9,
                onTap: () => onChanged(value + 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String tooltip;
  final PhosphorIconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primaryAccent,
        disabledForegroundColor: AppColors.textSecondary,
      ),
      icon: PhosphorIcon(icon, size: 18),
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
