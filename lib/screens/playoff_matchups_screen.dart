import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/app_user.dart';
import '../models/leaderboard_entry.dart';
import '../models/match_prediction.dart';
import '../models/playoff.dart';
import '../services/leaderboard_service.dart';
import '../services/playoff_service.dart';
import '../services/prediction_service.dart';
import '../services/session_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar_badge.dart';

/// Matchup comparison screen for the knockout bracket.
class PlayoffMatchupsScreen extends StatefulWidget {
  const PlayoffMatchupsScreen({
    super.key,
    required this.sessionController,
    this.playoffService,
  });

  final SessionController sessionController;
  final PlayoffService? playoffService;

  @override
  State<PlayoffMatchupsScreen> createState() => _PlayoffMatchupsScreenState();
}

class _PlayoffMatchupsScreenState extends State<PlayoffMatchupsScreen> {
  late final PlayoffService _playoffService =
      widget.playoffService ?? PlayoffService();
  late final LeaderboardService _leaderboardService = LeaderboardService();
  late final PredictionService _predictionService = PredictionService();

  PlayoffBracket? _bracket;
  List<PlayoffRoundScore> _roundScores = [];
  List<MatchPredictionResults> _roundPredictionResults = [];
  bool _isLoading = true;
  bool _isLoadingScores = false;
  int _roundIndex = 0;
  int _matchIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadBracket();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rounds = _rounds;
    final selectedRound = rounds.isEmpty ? null : rounds[_roundIndex];
    final safeMatchIndex =
        selectedRound == null || selectedRound.matches.isEmpty
        ? 0
        : _matchIndex.clamp(0, selectedRound.matches.length - 1).toInt();
    final selectedMatch = selectedRound == null || selectedRound.matches.isEmpty
        ? null
        : selectedRound.matches[safeMatchIndex];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar para o bracket',
          onPressed: () => context.go('/playoff'),
          icon: PhosphorIcon(PhosphorIcons.caretLeft()),
        ),
        title: const Text('Confrontos'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _isLoading ? null : _loadBracket,
            icon: PhosphorIcon(PhosphorIcons.clockCounterClockwise()),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
          children: [
            Text('Mata-mata', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Compare os placares e pontos de cada duelo da rodada.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (rounds.isEmpty)
              const _SurfaceMessage(
                message: 'Nenhum confronto de mata-mata encontrado.',
              )
            else ...[
              _MatchupDropdown(
                round: selectedRound!,
                selectedMatch: selectedMatch!,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _matchIndex = value);
                },
              ),
              const SizedBox(height: 14),
              _RoundStatusBar(match: selectedMatch),
              const SizedBox(height: 14),
              if (_isLoadingScores)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _MatchupComparison(
                  match: selectedMatch,
                  scoresByUserId: _scoresByUserId,
                  roundPredictionResults: _roundPredictionResults,
                ).animate().fadeIn(duration: 220.ms).slideY(begin: .04),
              const SizedBox(height: 18),
              _RoundPager(
                rounds: rounds,
                currentIndex: _roundIndex,
                onPrevious: _roundIndex == 0
                    ? null
                    : () => _selectRound(_roundIndex - 1),
                onNext: _roundIndex >= rounds.length - 1
                    ? null
                    : () => _selectRound(_roundIndex + 1),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_PlayoffRound> get _rounds {
    final bracket = _bracket;
    if (bracket == null) return [];

    final grouped = <String, List<PlayoffMatch>>{};
    for (final match in _matchesForDisplay(bracket)) {
      grouped.putIfAbsent(match.round, () => []).add(match);
    }

    final rounds =
        grouped.entries
            .map(
              (entry) => _PlayoffRound(
                code: entry.key,
                label: _roundLabel(entry.key),
                matches: entry.value
                  ..sort((a, b) => a.position.compareTo(b.position)),
              ),
            )
            .toList()
          ..sort((a, b) => _roundOrder(a.code).compareTo(_roundOrder(b.code)));

    return rounds;
  }

  Map<String, PlayoffRoundScore> get _scoresByUserId {
    return {for (final score in _roundScores) score.userId: score};
  }

  Future<void> _loadBracket() async {
    setState(() {
      _isLoading = true;
      _isLoadingScores = false;
    });

    try {
      final bracket =
          await _playoffService.loadCurrentBracket() ?? await _previewBracket();
      if (!mounted) return;
      setState(() {
        _bracket = bracket;
        _roundIndex = 0;
        _matchIndex = 0;
        _isLoading = false;
      });
      await _loadRoundScores();
    } catch (error) {
      debugPrint('Falha ao carregar confrontos: $error');
      if (!mounted) return;
      setState(() {
        _bracket = null;
        _roundScores = [];
        _roundPredictionResults = [];
        _isLoading = false;
      });
      _showMessage('Nao foi possivel carregar os confrontos.');
    }
  }

  Future<void> _loadRoundScores() async {
    final rounds = _rounds;
    if (rounds.isEmpty) return;

    setState(() {
      _isLoadingScores = true;
      _roundScores = [];
      _roundPredictionResults = [];
    });

    var scores = <PlayoffRoundScore>[];
    var predictionResults = <MatchPredictionResults>[];
    final roundCode = rounds[_roundIndex].code;

    try {
      scores = await _playoffService.loadRoundScore(roundCode);
    } catch (error) {
      debugPrint('Falha ao carregar pontuacao da rodada: $error');
    }

    try {
      predictionResults = await _loadFinishedPredictionResults(roundCode);
    } catch (error) {
      debugPrint('Falha ao carregar placares palpitados da rodada: $error');
    }

    if (!mounted) return;
    setState(() {
      _roundScores = scores;
      _roundPredictionResults = predictionResults;
      _isLoadingScores = false;
    });
  }

  Future<List<MatchPredictionResults>> _loadFinishedPredictionResults(
    String round,
  ) async {
    final user = widget.sessionController.currentUser;
    if (user == null) return [];

    final matches = await _predictionService.loadMatches();
    final finishedMatches = matches
        .where(
          (match) =>
              _sameRound(match.round, round) &&
              match.isPlayoffMatch &&
              match.isFinished,
        )
        .toList();

    final results = <MatchPredictionResults>[];
    for (final match in finishedMatches) {
      results.add(
        await _predictionService.loadMatchPredictionResults(
          user: user,
          fixtureId: match.fixtureId,
        ),
      );
    }
    return results;
  }

  void _selectRound(int index) {
    setState(() {
      _roundIndex = index;
      _matchIndex = 0;
    });
    _loadRoundScores();
  }

  List<PlayoffMatch> _matchesForDisplay(PlayoffBracket bracket) {
    if (bracket.matches.isNotEmpty) return bracket.matches;
    return _buildFirstRoundFallback(bracket.participants);
  }

  Future<PlayoffBracket> _previewBracket() async {
    final user = widget.sessionController.currentUser;
    if (user == null) {
      return _buildPreviewBracket([]);
    }

    try {
      final entries = await _leaderboardService.loadLeaderboard(user);
      return _buildPreviewBracket(entries);
    } catch (error) {
      debugPrint('Falha ao carregar ranking para preview do mata-mata: $error');
      return _buildPreviewBracket([_fallbackEntry(user)]);
    }
  }

  PlayoffBracket _buildPreviewBracket(List<LeaderboardEntry> entries) {
    final participants = entries
        .take(32)
        .map(
          (entry) => PlayoffParticipant(
            userId: entry.userId,
            seed: entry.position,
            nick: entry.nick,
            avatarId: entry.avatarId,
            photoUrl: entry.photoUrl,
            rankingPoints: entry.points,
          ),
        )
        .toList();

    return PlayoffBracket(
      id: 'preview',
      maxParticipants: 32,
      generatedAt: DateTime.now().toUtc().toIso8601String(),
      participants: participants,
      matches: _buildFirstRoundFallback(participants),
    );
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

  List<PlayoffMatch> _buildFirstRoundFallback(
    List<PlayoffParticipant> participants,
  ) {
    final bySeed = {
      for (final participant in participants) participant.seed: participant,
    };
    final matches = <PlayoffMatch>[];
    for (var index = 0; index < _rd32SeedOrder.length; index += 2) {
      matches.add(
        PlayoffMatch(
          id: 'rd32-${index ~/ 2 + 1}',
          round: 'RD32',
          roundIndex: 0,
          position: index ~/ 2 + 1,
          participantA: bySeed[_rd32SeedOrder[index]],
          participantB: bySeed[_rd32SeedOrder[index + 1]],
          status: 'pending',
          isBye: bySeed[_rd32SeedOrder[index + 1]] == null,
        ),
      );
    }
    return matches;
  }

  String _roundLabel(String round) {
    final normalized = round.trim().toUpperCase();
    return switch (normalized) {
      'RD32' || 'R32' || 'ROUND_OF_32' => 'RD32',
      'RD16' || 'R16' || 'ROUND_OF_16' => 'RD16',
      'QF' || 'QUARTER' || 'QUARTER_FINAL' => 'Quartas',
      'SF' || 'SEMI' || 'SEMI_FINAL' => 'Semis',
      'F' || 'FINAL' => 'Final',
      _ => round,
    };
  }

  int _roundOrder(String round) {
    final normalized = round.trim().toUpperCase();
    return switch (normalized) {
      'RD32' || 'R32' || 'ROUND_OF_32' => 0,
      'RD16' || 'R16' || 'ROUND_OF_16' => 1,
      'QF' || 'QUARTER' || 'QUARTER_FINAL' => 2,
      'SF' || 'SEMI' || 'SEMI_FINAL' => 3,
      'F' || 'FINAL' => 4,
      _ => 99,
    };
  }

  bool _sameRound(String matchRound, String selectedRound) {
    return _roundKey(matchRound) == _roundKey(selectedRound);
  }

  String _roundKey(String round) {
    final normalized = round.trim().toUpperCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    return switch (normalized) {
      'RD32' || 'R32' || 'ROUND_OF_32' || '1/16' || '16_AVOS' => 'round_of_32',
      'RD16' || 'R16' || 'ROUND_OF_16' || '1/8' || 'OITAVAS' => 'round_of_16',
      'QF' ||
      'QUARTER' ||
      'QUARTER_FINAL' ||
      'QUARTER_FINALS' ||
      'QUARTAS' => 'quarter_final',
      'SF' ||
      'SEMI' ||
      'SEMI_FINAL' ||
      'SEMI_FINALS' ||
      'SEMIS' => 'semi_final',
      'F' || 'FINAL' => 'final',
      _ => normalized.toLowerCase(),
    };
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

class _MatchupDropdown extends StatelessWidget {
  const _MatchupDropdown({
    required this.round,
    required this.selectedMatch,
    required this.onChanged,
  });

  final _PlayoffRound round;
  final PlayoffMatch selectedMatch;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = round.matches.indexWhere(
      (match) => match.id == selectedMatch.id,
    );

    return DropdownButtonFormField<int>(
      value: selectedIndex < 0 ? 0 : selectedIndex,
      icon: PhosphorIcon(PhosphorIcons.caretDown()),
      decoration: const InputDecoration(labelText: 'Resultado dos confrontos'),
      items: [
        for (var index = 0; index < round.matches.length; index++)
          DropdownMenuItem(
            value: index,
            child: Text(
              _matchLabel(round.matches[index]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

class _RoundStatusBar extends StatelessWidget {
  const _RoundStatusBar({required this.match});

  final PlayoffMatch match;

  @override
  Widget build(BuildContext context) {
    final isFinished =
        match.status.toLowerCase() == 'finished' ||
        match.status.toLowerCase() == 'done';
    final color = isFinished
        ? AppColors.primaryAccent
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          PhosphorIcon(
            isFinished ? PhosphorIcons.checkCircle() : PhosphorIcons.clock(),
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              match.isBye ? 'Confronto com bye' : _matchLabel(match),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _StatusChip(status: match.status),
        ],
      ),
    );
  }
}

class _MatchupComparison extends StatelessWidget {
  const _MatchupComparison({
    required this.match,
    required this.scoresByUserId,
    required this.roundPredictionResults,
  });

  final PlayoffMatch match;
  final Map<String, PlayoffRoundScore> scoresByUserId;
  final List<MatchPredictionResults> roundPredictionResults;

  @override
  Widget build(BuildContext context) {
    final participantA = match.participantA;
    final participantB = match.participantB;

    return Column(
      children: [
        _CompetitorScoreCard(
          participant: participantA,
          score: participantA == null
              ? null
              : scoresByUserId[participantA.userId],
          isWinner: participantA?.userId == match.winnerParticipantId,
        ),
        const SizedBox(height: 12),
        _VersusDivider(match: match),
        const SizedBox(height: 12),
        _CompetitorScoreCard(
          participant: participantB,
          score: participantB == null
              ? null
              : scoresByUserId[participantB.userId],
          isWinner: participantB?.userId == match.winnerParticipantId,
        ),
        const SizedBox(height: 14),
        _PredictionBreakdown(
          participantA: participantA,
          participantB: participantB,
          results: roundPredictionResults,
        ),
      ],
    );
  }
}

class _PredictionBreakdown extends StatelessWidget {
  const _PredictionBreakdown({
    required this.participantA,
    required this.participantB,
    required this.results,
  });

  final PlayoffParticipant? participantA;
  final PlayoffParticipant? participantB;
  final List<MatchPredictionResults> results;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.checkCircle(),
                size: 18,
                color: AppColors.primaryAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Placares contabilizados',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (results.isEmpty)
            Text(
              'Os placares aparecem aqui apos os jogos da rodada terminarem.',
              style: theme.textTheme.bodyMedium,
            )
          else
            for (final result in results)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PredictionResultRow(
                  result: result,
                  participantA: participantA,
                  participantB: participantB,
                ),
              ),
        ],
      ),
    );
  }
}

class _PredictionResultRow extends StatelessWidget {
  const _PredictionResultRow({
    required this.result,
    required this.participantA,
    required this.participantB,
  });

  final MatchPredictionResults result;
  final PlayoffParticipant? participantA;
  final PlayoffParticipant? participantB;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final predictionA = _predictionFor(participantA);
    final predictionB = _predictionFor(participantB);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${result.homeTeam} ${result.homeScore} x ${result.awayScore} ${result.awayTeam}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _PredictionPill(
                  participant: participantA,
                  prediction: predictionA,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _PredictionPill(
                  participant: participantB,
                  prediction: predictionB,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PublicPredictionResult? _predictionFor(PlayoffParticipant? participant) {
    if (participant == null) return null;
    for (final prediction in result.predictions) {
      if (prediction.userId == participant.userId) return prediction;
    }
    return null;
  }
}

class _PredictionPill extends StatelessWidget {
  const _PredictionPill({required this.participant, required this.prediction});

  final PlayoffParticipant? participant;
  final PublicPredictionResult? prediction;

  @override
  Widget build(BuildContext context) {
    final scored = (prediction?.points ?? 0) > 0;

    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scored
            ? AppColors.primaryAccent.withValues(alpha: .12)
            : AppColors.background,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(
          color: scored
              ? AppColors.primaryAccent.withValues(alpha: .35)
              : Colors.white.withValues(alpha: .05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            participant?.nick ?? 'A definir',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            prediction == null
                ? 'Sem palpite'
                : '${prediction!.predictedHomeScore} x ${prediction!.predictedAwayScore} - ${prediction!.points} pts',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scored ? AppColors.primaryAccent : AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompetitorScoreCard extends StatelessWidget {
  const _CompetitorScoreCard({
    required this.participant,
    required this.score,
    required this.isWinner,
  });

  final PlayoffParticipant? participant;
  final PlayoffRoundScore? score;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = participant == null;
    final borderColor = isWinner
        ? AppColors.primaryAccent.withValues(alpha: .7)
        : Colors.white.withValues(alpha: .06);
    final background = isWinner
        ? AppColors.primaryAccent.withValues(alpha: .1)
        : AppColors.surface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              isEmpty ? 'BYE' : '#${participant!.seed}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: isWinner
                    ? AppColors.primaryAccent
                    : AppColors.textPrimary,
              ),
            ),
          ),
          AvatarBadge(
            avatarId: participant?.avatarId ?? 'target',
            photoUrl: participant?.photoUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant?.nick ?? 'Aguardando adversario',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
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
                        '${score?.predictionsCount ?? 0} placares - ${score?.exactScores ?? 0} exatos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.checkCircle(),
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${score?.correctQualified ?? 0} classificados corretos',
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
              color: isWinner || (score?.points ?? 0) > 0
                  ? AppColors.primaryAccent
                  : AppColors.background,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              '${score?.points ?? 0} pts',
              style: TextStyle(
                color: isWinner || (score?.points ?? 0) > 0
                    ? Colors.black
                    : AppColors.textSecondary,
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

class _VersusDivider extends StatelessWidget {
  const _VersusDivider({required this.match});

  final PlayoffMatch match;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.surfaceElevated)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            match.isBye ? 'BYE' : 'VS',
            style: const TextStyle(
              color: AppColors.primaryAccent,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.surfaceElevated)),
      ],
    );
  }
}

class _RoundPager extends StatelessWidget {
  const _RoundPager({
    required this.rounds,
    required this.currentIndex,
    required this.onPrevious,
    required this.onNext,
  });

  final List<_PlayoffRound> rounds;
  final int currentIndex;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Rodada anterior',
            onPressed: onPrevious,
            icon: PhosphorIcon(PhosphorIcons.caretLeft()),
          ),
          Expanded(
            child: SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: rounds.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) => _RoundChip(
                  label: rounds[index].label,
                  isActive: index == currentIndex,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Proxima rodada',
            onPressed: onNext,
            icon: PhosphorIcon(PhosphorIcons.caretRight()),
          ),
        ],
      ),
    );
  }
}

class _RoundChip extends StatelessWidget {
  const _RoundChip({required this.label, required this.isActive});

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primaryAccent : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isActive ? Colors.black : AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final isFinished = normalized == 'finished' || normalized == 'done';
    final label = switch (normalized) {
      'pending' || '' => 'Pendente',
      'live' => 'Live',
      'finished' || 'done' => 'Finalizado',
      _ => status,
    };
    final color = isFinished
        ? AppColors.primaryAccent
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: .32)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isFinished ? AppColors.primaryAccent : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
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

class _PlayoffRound {
  const _PlayoffRound({
    required this.code,
    required this.label,
    required this.matches,
  });

  final String code;
  final String label;
  final List<PlayoffMatch> matches;
}

String _matchLabel(PlayoffMatch match) {
  final participantA = match.participantA?.nick ?? 'A definir';
  final participantB = match.participantB?.nick ?? 'A definir';
  return '${match.round} #${match.position} - $participantA x $participantB';
}

const _rd32SeedOrder = [
  1,
  32,
  16,
  17,
  8,
  25,
  9,
  24,
  4,
  29,
  13,
  20,
  5,
  28,
  12,
  21,
  2,
  31,
  15,
  18,
  7,
  26,
  10,
  23,
  3,
  30,
  14,
  19,
  6,
  27,
  11,
  22,
];
