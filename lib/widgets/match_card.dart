import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';

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
    return '$homeScore - $awayScore';
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
              fontSize: 28,
              fontWeight: FontWeight.w900,
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

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.surfaceElevated,
      child: ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: CountryFlag.fromCountryCode(
            code,
            theme: ImageTheme(width: size, height: size, shape: const Circle()),
          ),
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
    final isFinished = normalized == 'FT';
    final color = isLive
        ? AppColors.liveBadge
        : isFinished
        ? AppColors.textSecondary
        : AppColors.secondaryAccent;
    final label = isLive
        ? 'Live'
        : isFinished
        ? 'FT'
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

/// Maps national team names to ISO 3166 country codes for flags.
String countryCodeForTeam(String teamName) {
  final normalized = _normalizeTeamName(teamName);
  return switch (normalized) {
    'argentina' => 'AR',
    'australia' => 'AU',
    'austria' => 'AT',
    'belgium' || 'belgica' => 'BE',
    'bolivia' => 'BO',
    'brazil' => 'BR',
    'brasil' => 'BR',
    'cameroon' || 'camaroes' => 'CM',
    'canada' => 'CA',
    'chile' => 'CL',
    'china' => 'CN',
    'colombia' => 'CO',
    'costa rica' => 'CR',
    'croatia' || 'croacia' => 'HR',
    'czech republic' || 'czechia' || 'republica tcheca' => 'CZ',
    'denmark' || 'dinamarca' => 'DK',
    'ecuador' => 'EC',
    'egypt' || 'egito' => 'EG',
    'england' || 'inglaterra' => 'GB',
    'france' => 'FR',
    'franca' => 'FR',
    'germany' => 'DE',
    'alemanha' => 'DE',
    'ghana' => 'GH',
    'greece' || 'grecia' => 'GR',
    'hungary' || 'hungria' => 'HU',
    'iran' => 'IR',
    'iraq' || 'iraque' => 'IQ',
    'ireland' || 'irlanda' => 'IE',
    'italy' || 'italia' => 'IT',
    'japan' => 'JP',
    'japao' => 'JP',
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
    'scotland' || 'escocia' => 'GB',
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
    'venezuela' => 'VE',
    'wales' || 'pais de gales' => 'GB',
    _ => 'US',
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
