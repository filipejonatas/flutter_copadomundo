import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/match_prediction.dart';
import '../theme/app_theme.dart';

/// Premium dark match card with team flags, score, and status chip.
class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    this.homeScoreOverride,
    this.awayScoreOverride,
    this.footer,
    this.onTap,
  });

  final MatchPrediction match;
  final int? homeScoreOverride;
  final int? awayScoreOverride;
  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scoreText = _scoreText;

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _TeamSide(name: match.homeTeam)),
              const SizedBox(width: 12),
              _ScoreColumn(scoreText: scoreText, status: match.status),
              const SizedBox(width: 12),
              Expanded(child: _TeamSide(name: match.awayTeam)),
            ],
          ),
          if (footer != null) ...[const SizedBox(height: 16), footer!],
        ],
      ),
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: onTap,
        child: card,
      ),
    );
  }

  String get _scoreText {
    final homeScore = homeScoreOverride ?? match.homeScore;
    final awayScore = awayScoreOverride ?? match.awayScore;
    if (homeScore == null || awayScore == null) return 'VS';
    final baseScore = '$homeScore - $awayScore';
    final homePenaltyScore = match.homePenaltyScore;
    final awayPenaltyScore = match.awayPenaltyScore;
    if (homePenaltyScore == null || awayPenaltyScore == null) {
      return baseScore;
    }
    return '$baseScore\n($homePenaltyScore - $awayPenaltyScore)';
  }
}

class _TeamSide extends StatelessWidget {
  const _TeamSide({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TeamFlag(teamName: name),
        const SizedBox(height: 8),
        Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge,
        ),
      ],
    );
  }
}

class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({required this.scoreText, required this.status});

  final String scoreText;
  final String status;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        children: [
          Text(
            scoreText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 8),
          MatchStatusChip(status: status),
        ],
      ),
    );
  }
}

/// Circular national team flag rendered from a team name.
class TeamFlag extends StatelessWidget {
  const TeamFlag({super.key, required this.teamName, this.size = 48});

  final String teamName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final code = countryCodeForTeam(teamName);

    if (code == null) {
      return _FlagFallback(teamName: teamName, size: size);
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _FlagFallback(teamName: teamName, size: size),
          ClipOval(
            child: SvgPicture.asset(
              flagAssetPathForCode(code),
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholderBuilder: (_) =>
                  _FlagFallback(teamName: teamName, size: size),
              errorBuilder: (_, _, _) =>
                  _FlagFallback(teamName: teamName, size: size),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlagFallback extends StatelessWidget {
  const _FlagFallback({required this.teamName, required this.size});

  final String teamName;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceElevated,
      child: Text(
        _fallbackFlagLabel(teamName),
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: size * .28,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

/// Pill-shaped status chip for live, finished, and upcoming matches.
class MatchStatusChip extends StatelessWidget {
  const MatchStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final isLive =
        normalized == 'LIVE' || normalized == '1H' || normalized == '2H';
    final isFinished = isFinishedMatchStatus(normalized);
    final color = isLive
        ? AppColors.liveBadge
        : isFinished
        ? AppColors.textSecondary
        : AppColors.secondaryAccent;
    final label = isLive
        ? 'Live'
        : isFinished
        ? (normalized == 'FT_PEN' ? 'PEN' : 'FT')
        : status == 'NS'
        ? 'Today'
        : status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: .38)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == AppColors.textSecondary
              ? AppColors.textPrimary
              : color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String flagAssetPathForCode(String code) =>
    'assets/flags/${code.toLowerCase()}.svg';

/// Maps national team names to ISO 3166 country codes for flags.
String? countryCodeForTeam(String teamName) {
  final normalized = _normalizeTeamName(teamName);
  return switch (normalized) {
    '' => null,
    'algeria' || 'argelia' => 'DZ',
    'argentina' => 'AR',
    'australia' => 'AU',
    'austria' => 'AT',
    'belgium' || 'belgica' => 'BE',
    'bolivia' => 'BO',
    'bosnia herzegovina' ||
    'bosnia and herzegovina' ||
    'bosnia e herzegovina' => 'BA',
    'brazil' => 'BR',
    'brasil' => 'BR',
    'cabo verde' || 'cape verde' => 'CV',
    'cameroon' || 'camaroes' => 'CM',
    'canada' => 'CA',
    'chile' => 'CL',
    'china' => 'CN',
    'colombia' => 'CO',
    'congo dr' ||
    'dr congo' ||
    'congo democratic republic' ||
    'democratic republic of congo' ||
    'republica democratica do congo' => 'CD',
    'costa rica' => 'CR',
    'cote d ivoire' ||
    'c te d ivoire' ||
    'ivory coast' ||
    'costa do marfim' => 'CI',
    'croatia' || 'croacia' => 'HR',
    'curacao' || 'cura ao' || 'curacau' => 'CW',
    'czech republic' || 'czechia' || 'republica tcheca' => 'CZ',
    'denmark' || 'dinamarca' => 'DK',
    'ecuador' => 'EC',
    'egypt' || 'egito' => 'EG',
    'england' || 'inglaterra' => 'GB-ENG',
    'france' => 'FR',
    'franca' => 'FR',
    'germany' => 'DE',
    'alemanha' => 'DE',
    'ghana' => 'GH',
    'greece' || 'grecia' => 'GR',
    'haiti' => 'HT',
    'hungary' || 'hungria' => 'HU',
    'iran' || 'ir iran' => 'IR',
    'iraq' || 'iraque' => 'IQ',
    'ireland' || 'irlanda' => 'IE',
    'italy' || 'italia' => 'IT',
    'japan' => 'JP',
    'japao' => 'JP',
    'jordan' || 'jordania' => 'JO',
    'korea republic' ||
    'south korea' ||
    'coreia do sul' ||
    'republica da coreia' => 'KR',
    'mexico' => 'MX',
    'morocco' || 'marrocos' => 'MA',
    'netherlands' || 'holanda' || 'paises baixos' => 'NL',
    'new zealand' || 'nova zelandia' => 'NZ',
    'nigeria' => 'NG',
    'norway' || 'noruega' => 'NO',
    'panama' => 'PA',
    'paraguay' || 'paraguai' => 'PY',
    'peru' => 'PE',
    'poland' || 'polonia' => 'PL',
    'portugal' => 'PT',
    'qatar' || 'catar' => 'QA',
    'romania' || 'romenia' => 'RO',
    'russia' => 'RU',
    'saudi arabia' || 'arabia saudita' => 'SA',
    'scotland' || 'escocia' => 'GB-SCT',
    'senegal' => 'SN',
    'serbia' || 'servia' => 'RS',
    'slovakia' || 'eslovaquia' => 'SK',
    'slovenia' || 'eslovenia' => 'SI',
    'south africa' => 'ZA',
    'africa do sul' => 'ZA',
    'spain' || 'espanha' => 'ES',
    'sweden' || 'suecia' => 'SE',
    'switzerland' || 'suica' => 'CH',
    'tunisia' => 'TN',
    'turkey' || 'turkiye' || 'turquia' => 'TR',
    'ukraine' || 'ucrania' => 'UA',
    'united states' || 'usa' || 'usmnt' || 'estados unidos' => 'US',
    'uruguay' => 'UY',
    'uzbekistan' || 'uzbequistao' => 'UZ',
    'venezuela' => 'VE',
    'wales' || 'pais de gales' => 'GB-WLS',
    _ => null,
  };
}

String _normalizeTeamName(String value) {
  final lower = value.trim().toLowerCase();
  final withoutAccents = lower
      .replaceAll(RegExp('[áàâãä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôõö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll('ñ', 'n');
  return withoutAccents
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _fallbackFlagLabel(String teamName) {
  final normalized = _normalizeTeamName(teamName);
  if (normalized.isEmpty) return 'TBD';

  final words = normalized.split(' ');
  if (words.length == 1) {
    return words.first.substring(0, 1).toUpperCase();
  }

  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}
