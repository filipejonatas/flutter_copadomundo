import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/app_user.dart';
import '../models/match_prediction.dart';
import '../services/prediction_service.dart';
import '../services/session_controller.dart';
import '../theme/app_theme.dart';
import '../utils/match_day_selector.dart';
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
  final Map<int, UserMatchPrediction> _drafts = {};
  List<MatchPrediction> _matches = [];
  late final PredictionService _predictionService =
      widget.predictionService ?? PredictionService();
  bool _isLoading = true;
  bool _isSavingAll = false;
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
            Text(
              'Mata-mata',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.primaryAccent,
              ),
            ),
            const SizedBox(height: 4),
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
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE45CFF),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: _canSaveAll ? _saveAllPredictions : null,
                    icon: _isSavingAll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : PhosphorIcon(PhosphorIcons.floppyDisk()),
                    label: Text(
                      _isSavingAll ? 'Salvando palpites...' : 'Salvar todos',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(visibleDay!.label, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                for (final match in visibleDay.matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PredictionCard(
                      key: ValueKey(match.fixtureId),
                      match: match,
                      draftPrediction: _drafts[match.fixtureId],
                      savedPrediction: _picks[match.fixtureId],
                      isSaving: _savingFixtureId == match.fixtureId,
                      isLocked: !match.isPredictionOpen(),
                      onDraftChanged: (prediction) {
                        _drafts[match.fixtureId] = prediction;
                      },
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
    return _buildMatchDays(_matches);
  }

  bool get _canSaveAll {
    return !_isSavingAll &&
        _savingFixtureId == null &&
        _matches.any((match) => match.isPredictionOpen());
  }

  List<_MatchDay> _buildMatchDays(List<MatchPrediction> matches) {
    final days = <String, List<MatchPrediction>>{};
    for (final match in matches) {
      days.putIfAbsent(_dayLabel(match), () => []).add(match);
    }

    return days.entries
        .map((entry) => _MatchDay(label: entry.key, matches: entry.value))
        .toList();
  }

  Future<void> _loadPredictions() async {
    final user = widget.sessionController.currentUser;
    if (user == null) return;

    List<MatchPrediction> matches;
    try {
      matches = await _predictionService.loadMatches();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _matches = [];
        _dayIndex = 0;
        _picks.clear();
        _isLoading = false;
      });
      _showMessage('Nao foi possivel carregar jogos da API.');
      debugPrint('Falha ao carregar jogos: $error');
      return;
    }

    Map<int, UserMatchPrediction> predictions = {};
    try {
      predictions = await _predictionService.loadUserPredictions(user);
    } catch (error) {
      debugPrint('Falha ao carregar palpites do usuario: $error');
      _showMessage('Nao foi possivel carregar seus palpites salvos.');
    }

    if (!mounted) return;
    final matchDays = _buildMatchDays(matches);
    setState(() {
      _matches = matches;
      _dayIndex = initialMatchDayIndex(
        matchDays.map((day) => day.matches).toList(),
      );
      _picks
        ..clear()
        ..addAll(predictions);
      _drafts
        ..clear()
        ..addEntries(
          matches.map(
            (match) => MapEntry(
              match.fixtureId,
              predictions[match.fixtureId] ??
                  const UserMatchPrediction(
                    pick: MatchPick.draw,
                    homeScore: 0,
                    awayScore: 0,
                  ),
            ),
          ),
        );
      _isLoading = false;
    });
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
        _drafts[match.fixtureId] = prediction;
      });
      _showMessage('Palpite salvo.');
    } catch (error) {
      debugPrint('Falha ao salvar palpite: $error');
      if (!mounted) return;
      _showMessage('Nao foi possivel salvar o palpite.');
    } finally {
      if (mounted) {
        setState(() => _savingFixtureId = null);
      }
    }
  }

  Future<void> _saveAllPredictions() async {
    final AppUser? user = widget.sessionController.currentUser;
    if (user == null) return;

    final predictions = <MatchPrediction, UserMatchPrediction>{};
    for (final match in _matches) {
      final prediction = _drafts[match.fixtureId];
      if (prediction == null || !match.isPredictionOpen()) continue;
      predictions[match] = prediction;
    }
    if (predictions.isEmpty) {
      _showMessage('Nenhum jogo aberto para salvar.');
      return;
    }

    setState(() => _isSavingAll = true);
    try {
      await _predictionService.savePredictionsBulk(
        user: user,
        predictions: predictions,
      );
      if (!mounted) return;
      setState(() {
        for (final entry in predictions.entries) {
          _picks[entry.key.fixtureId] = entry.value;
        }
      });
      _showMessage('${predictions.length} palpites salvos.');
    } catch (error) {
      debugPrint('Falha ao salvar todos os palpites: $error');
      if (!mounted) return;
      _showMessage('Nao foi possivel salvar todos os palpites.');
    } finally {
      if (mounted) setState(() => _isSavingAll = false);
    }
  }

  String _dayLabel(MatchPrediction match) {
    final labelParts = match.kickoffLabel.split(',');
    if (labelParts.isEmpty) return 'Dia do jogo';
    return labelParts.first.trim();
  }

  void _showMessage(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    });
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
    required this.draftPrediction,
    required this.savedPrediction,
    required this.isSaving,
    required this.isLocked,
    required this.onDraftChanged,
    required this.onSave,
  });

  final MatchPrediction match;
  final UserMatchPrediction? draftPrediction;
  final UserMatchPrediction? savedPrediction;
  final bool isSaving;
  final bool isLocked;
  final ValueChanged<UserMatchPrediction> onDraftChanged;
  final ValueChanged<UserMatchPrediction> onSave;

  @override
  State<_PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends State<_PredictionCard> {
  late int _homeScore;
  late int _awayScore;
  MatchPick? _qualifiedPick;

  @override
  void initState() {
    super.initState();
    _syncFromWidget();
  }

  @override
  void didUpdateWidget(covariant _PredictionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.match.fixtureId != widget.match.fixtureId ||
        oldWidget.draftPrediction != widget.draftPrediction) {
      _syncFromWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    final prediction = _draftPrediction;
    final hasSavedPrediction = widget.savedPrediction != null;
    final canEdit = !widget.isSaving && !widget.isLocked;

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
                  enabled: canEdit,
                  onChanged: (value) {
                    setState(() => _homeScore = value);
                    widget.onDraftChanged(_draftPrediction);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ScoreStepper(
                  label: widget.match.awayTeam,
                  value: _awayScore,
                  enabled: canEdit,
                  onChanged: (value) {
                    setState(() => _awayScore = value);
                    widget.onDraftChanged(_draftPrediction);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_shouldAskQualifiedPick) ...[
            _QualifiedPickSelector(
              homeTeam: widget.match.homeTeam,
              awayTeam: widget.match.awayTeam,
              value: _qualifiedPick ?? MatchPick.home,
              enabled: canEdit,
              onChanged: (value) {
                setState(() => _qualifiedPick = value);
                widget.onDraftChanged(_draftPrediction);
              },
            ),
            const SizedBox(height: 14),
          ],
          FilledButton.icon(
            onPressed: canEdit ? () => widget.onSave(prediction) : null,
            icon: widget.isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : PhosphorIcon(PhosphorIcons.checkCircle()),
            label: Text(
              widget.isSaving
                  ? 'Confirmando...'
                  : hasSavedPrediction
                  ? 'Atualizar palpite'
                  : 'Confirmar palpite',
            ),
          ),
          if (widget.isLocked) ...[
            const SizedBox(height: 10),
            Text(
              'Palpites encerrados para este jogo.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (widget.savedPrediction != null) ...[
            const SizedBox(height: 10),
            Text(
              'Salvo: ${_predictionLabel(widget.savedPrediction!)}',
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
      qualifiedPick: _shouldAskQualifiedPick
          ? (_qualifiedPick ?? MatchPick.home)
          : null,
      homeScore: _homeScore,
      awayScore: _awayScore,
    );
  }

  bool get _shouldAskQualifiedPick {
    return widget.match.isPlayoffMatch && _homeScore == _awayScore;
  }

  void _syncFromWidget() {
    _homeScore = widget.draftPrediction?.homeScore ?? 0;
    _awayScore = widget.draftPrediction?.awayScore ?? 0;
    _qualifiedPick = widget.draftPrediction?.qualifiedPick ?? MatchPick.home;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDraftChanged(_draftPrediction);
    });
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

class _QualifiedPickSelector extends StatelessWidget {
  const _QualifiedPickSelector({
    required this.homeTeam,
    required this.awayTeam,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String homeTeam;
  final String awayTeam;
  final MatchPick value;
  final bool enabled;
  final ValueChanged<MatchPick> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Em caso de penaltis, quem passa?',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.primaryAccent,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: SegmentedButton<MatchPick>(
              segments: [
                ButtonSegment(
                  value: MatchPick.home,
                  label: Text(
                    homeTeam,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ButtonSegment(
                  value: MatchPick.away,
                  label: Text(
                    awayTeam,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              selected: {value},
              onSelectionChanged: enabled
                  ? (selected) => onChanged(selected.first)
                  : null,
            ),
          ),
        ],
      ),
    );
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
                width: 36,
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
        minimumSize: const Size.square(40),
        fixedSize: const Size.square(40),
        padding: EdgeInsets.zero,
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
