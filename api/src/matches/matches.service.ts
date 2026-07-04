import { BadGatewayException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { FirebaseAdminService } from '../firebase-admin.service';
import { WorldCupMatch } from './world-cup-match';

@Injectable()
export class MatchesService {
  private readonly logger = new Logger(MatchesService.name);
  private readonly persistentCachePath = 'cache/worldCup2026Matches';
  private cachedMatches: WorldCupMatch[] | null = null;
  private cachedMatchesAt = 0;
  private refreshPromise: Promise<WorldCupMatch[]> | null = null;

  constructor(
    private readonly configService: ConfigService,
    private readonly firebaseAdmin: FirebaseAdminService,
  ) {}

  async getWorldCup2026Matches(): Promise<WorldCupMatch[]> {
    const wcKey = this.configService.get<string>('WC2026_API_KEY');
    const hasWcKey = this.hasConfiguredKey(wcKey);

    if (!hasWcKey) {
      if (this.configService.get<string>('NODE_ENV') === 'production') {
        throw new Error('WC2026_API_KEY precisa estar configurada em producao.');
      }
      return this.getMockWorldCup2026Matches();
    }

    const configuredWcKey = this.normalizeKey(wcKey);
    const cacheTtlMs = this.positiveInt(
      this.configService.get<string>('WC2026_CACHE_TTL_SECONDS'),
      300,
    ) * 1000;
    if (
      this.cachedMatches !== null &&
      Date.now() - this.cachedMatchesAt < cacheTtlMs
    ) {
      return this.cachedMatches;
    }

    const baseUrl =
      this.configService.get<string>('WC2026_BASE_URL') ??
      'https://api.wc2026api.com';
    const url = new URL('/matches', baseUrl);
    const fetchTimeoutMs = this.positiveInt(
      this.configService.get<string>('WC2026_FETCH_TIMEOUT_MS'),
      7000,
    );

    const persistentMatches = await this.loadPersistentMatchesCache();
    if (persistentMatches.length > 0) {
      this.cachedMatches = persistentMatches;
      this.cachedMatchesAt = Date.now();
      this.refreshMatchesCache(url, configuredWcKey, fetchTimeoutMs).catch(
        (error: unknown) => {
          this.logger.warn(
            `Refresh em background dos jogos falhou: ${this.errorMessage(error)}`,
          );
        },
      );
      return persistentMatches;
    }

    return this.refreshMatchesCache(url, configuredWcKey, fetchTimeoutMs);
  }

  async refreshWorldCup2026Matches(): Promise<WorldCupMatch[]> {
    const wcKey = this.configService.get<string>('WC2026_API_KEY');
    const hasWcKey = this.hasConfiguredKey(wcKey);

    if (!hasWcKey) {
      if (this.configService.get<string>('NODE_ENV') === 'production') {
        throw new Error('WC2026_API_KEY precisa estar configurada em producao.');
      }
      return this.getMockWorldCup2026Matches();
    }

    const baseUrl =
      this.configService.get<string>('WC2026_BASE_URL') ??
      'https://api.wc2026api.com';
    const url = new URL('/matches', baseUrl);
    const fetchTimeoutMs = this.positiveInt(
      this.configService.get<string>('WC2026_FETCH_TIMEOUT_MS'),
      7000,
    );

    return this.fetchAndCacheWc2026Matches(
      url,
      this.normalizeKey(wcKey),
      fetchTimeoutMs,
    );
  }

  private async refreshMatchesCache(
    url: URL,
    configuredWcKey: string,
    fetchTimeoutMs: number,
  ): Promise<WorldCupMatch[]> {
    if (this.refreshPromise !== null) {
      return this.refreshPromise;
    }

    this.refreshPromise = this.fetchAndCacheWc2026Matches(
      url,
      configuredWcKey,
      fetchTimeoutMs,
    ).finally(() => {
      this.refreshPromise = null;
    });
    return this.refreshPromise;
  }

  private async fetchAndCacheWc2026Matches(
    url: URL,
    configuredWcKey: string,
    fetchTimeoutMs: number,
  ): Promise<WorldCupMatch[]> {
    const payload = await this.fetchWc2026Matches(
      url,
      configuredWcKey,
      fetchTimeoutMs,
    );
    if (!Array.isArray(payload)) {
      return this.getMockWorldCup2026Matches();
    }

    const matches = this.toWorldCupMatches(payload);
    this.cachedMatches = matches;
    this.cachedMatchesAt = Date.now();
    await this.savePersistentMatchesCache(matches);
    return matches;
  }

  private async fetchWc2026Matches(
    url: URL,
    configuredWcKey: string,
    fetchTimeoutMs: number,
  ): Promise<Wc2026MatchesResponse> {
    const maxAttempts = 3;
    let lastError: unknown;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        const abortController = new AbortController();
        const timeout = setTimeout(() => abortController.abort(), fetchTimeoutMs);
        const response = await fetch(url, {
          headers: {
            Authorization: `Bearer ${configuredWcKey}`,
            Accept: 'application/json',
          },
          signal: abortController.signal,
        }).finally(() => clearTimeout(timeout));

        const responseBody = await response.text();
        if (!response.ok) {
          this.logger.error(
            `WC2026 API respondeu status ${response.status}: ${responseBody.slice(0, 500)}`,
          );
          throw new BadGatewayException('API de jogos respondeu com erro.');
        }

        return JSON.parse(responseBody) as Wc2026MatchesResponse;
      } catch (error) {
        lastError = error;
        this.logger.warn(
          `Tentativa ${attempt}/${maxAttempts} falhou ao consultar WC2026 API: ${this.errorMessage(error)}`,
        );
        if (attempt < maxAttempts) {
          await this.delay(350 * attempt);
        }
      }
    }

    if (this.cachedMatches !== null) {
      this.logger.warn('Usando cache em memoria da ultima resposta valida da WC2026 API.');
      return this.cachedMatches as Wc2026MatchesResponse;
    }

    const persistentMatches = await this.loadPersistentMatchesCache();
    if (persistentMatches.length > 0) {
      this.logger.warn('Usando cache persistente do Firebase para jogos da Copa.');
      this.cachedMatches = persistentMatches;
      this.cachedMatchesAt = Date.now();
      return persistentMatches as Wc2026MatchesResponse;
    }

    this.logger.error('Falha ao consultar WC2026 API apos novas tentativas.', lastError);
    throw new BadGatewayException('Nao foi possivel consultar a API de jogos.');
  }

  private toWorldCupMatches(payload: Wc2026MatchesResponse): WorldCupMatch[] {
    const matches = payload.map((m) => {
      if (this.isWorldCupMatch(m)) return m;

      const kickoff = m.kickoff_utc ?? m.kickoff ?? new Date().toISOString();
      const qualifiedPick = this.resolveQualifiedPick(m);
      return {
        fixtureId: m.id ?? m.match_number ?? 0,
        round: (m.round ?? '') + (m.group_name ? ` - ${m.group_name}` : ''),
        kickoffLabel: this.formatKickoffLabel(kickoff),
        kickoffAt: kickoff,
        homeTeam: m.home_team ?? '',
        awayTeam: m.away_team ?? '',
        status: m.phase ?? m.status ?? '',
        homeScore: this.resolveScore(m, 'home'),
        awayScore: this.resolveScore(m, 'away'),
        ...(qualifiedPick === undefined ? {} : { qualifiedPick }),
      };
    });
    return this.sortByKickoff(MatchesService.withInferredQualifiedPicks(matches));
  }

  static withInferredQualifiedPicks(matches: WorldCupMatch[]): WorldCupMatch[] {
    return matches.map((match) => {
      if (
        match.qualifiedPick !== undefined ||
        match.homeScore === undefined ||
        match.awayScore === undefined ||
        match.homeScore !== match.awayScore ||
        !MatchesService.isKnockoutRound(match.round)
      ) {
        return match;
      }

      const qualifiedPick = MatchesService.inferQualifiedPick(match, matches);
      return qualifiedPick === undefined ? match : { ...match, qualifiedPick };
    });
  }

  private async savePersistentMatchesCache(matches: WorldCupMatch[]): Promise<void> {
    try {
      await this.firebaseAdmin.database.ref(this.persistentCachePath).set({
        updatedAt: Date.now(),
        matches: matches.map((match) => ({
          fixtureId: match.fixtureId,
          round: match.round,
          kickoffLabel: match.kickoffLabel,
          kickoffAt: match.kickoffAt,
          homeTeam: match.homeTeam,
          awayTeam: match.awayTeam,
          status: match.status,
          ...(match.homeScore === undefined ? {} : { homeScore: match.homeScore }),
          ...(match.awayScore === undefined ? {} : { awayScore: match.awayScore }),
          ...(match.qualifiedPick === undefined
            ? {}
            : { qualifiedPick: match.qualifiedPick }),
        })),
      });
    } catch (error) {
      this.logger.warn(
        `Nao foi possivel salvar cache persistente de jogos: ${this.errorMessage(error)}`,
      );
    }
  }

  private async loadPersistentMatchesCache(): Promise<WorldCupMatch[]> {
    const snapshot = await this.firebaseAdmin.database
      .ref(this.persistentCachePath)
      .get()
      .catch((error: unknown) => {
        this.logger.warn(
          `Nao foi possivel carregar cache persistente de jogos: ${this.errorMessage(error)}`,
        );
        return null;
      });
    if (snapshot === null) return [];

    const value = snapshot.val() as { matches?: unknown } | null;
    if (!value || !Array.isArray(value.matches)) return [];

    const matches = value.matches.filter((item): item is WorldCupMatch =>
      this.isWorldCupMatch(item),
    );
    return this.sortByKickoff(MatchesService.withInferredQualifiedPicks(matches));
  }

  private getMockWorldCup2026Matches(): WorldCupMatch[] {
    return [
      {
        fixtureId: 2026001,
        round: 'Group Stage - 1',
        kickoffLabel: '11 jun, 16:00',
        kickoffAt: '2026-06-11T19:00:00Z',
        homeTeam: 'Mexico',
        awayTeam: 'South Africa',
        status: 'FT',
        homeScore: 2,
        awayScore: 1,
      },
      {
        fixtureId: 2026002,
        round: 'Group Stage - 1',
        kickoffLabel: '12 jun, 19:00',
        kickoffAt: '2026-06-12T22:00:00Z',
        homeTeam: 'Canada',
        awayTeam: 'Japan',
        status: 'FT',
        homeScore: 1,
        awayScore: 1,
      },
      {
        fixtureId: 2026003,
        round: 'Group Stage - 1',
        kickoffLabel: '13 jun, 13:00',
        kickoffAt: '2026-06-13T16:00:00Z',
        homeTeam: 'Brazil',
        awayTeam: 'Germany',
        status: 'NS',
      },
      {
        fixtureId: 2026004,
        round: 'Group Stage - 1',
        kickoffLabel: '14 jun, 21:00',
        kickoffAt: '2026-06-15T00:00:00Z',
        homeTeam: 'Argentina',
        awayTeam: 'France',
        status: 'NS',
      },
    ];
  }

  private formatKickoffLabel(dateValue: string): string {
    return new Intl.DateTimeFormat('pt-BR', {
      day: '2-digit',
      month: 'short',
      hour: '2-digit',
      minute: '2-digit',
      timeZone: 'America/Sao_Paulo',
    })
      .format(new Date(dateValue))
      .replace('.', '');
  }

  private hasConfiguredKey(value?: string): boolean {
    if (!value) return false;

    const trimmed = this.normalizeKey(value);
    return trimmed.length > 0 && trimmed !== 'coloque_sua_chave_aqui';
  }

  private normalizeKey(value?: string): string {
    return (value ?? '')
      .trim()
      .replace(/^['"]|['"]$/g, '')
      .replace(/^Bearer\s+/i, '')
      .trim();
  }

  private sortByKickoff(matches: WorldCupMatch[]): WorldCupMatch[] {
    return [...matches].sort(
      (a, b) =>
        new Date(a.kickoffAt).getTime() - new Date(b.kickoffAt).getTime(),
    );
  }

  private delay(milliseconds: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, milliseconds));
  }

  private errorMessage(error: unknown): string {
    if (error instanceof Error) return error.message;
    return String(error);
  }

  private isWorldCupMatch(value: unknown): value is WorldCupMatch {
    if (!value || typeof value !== 'object' || Array.isArray(value)) {
      return false;
    }

    const item = value as Partial<WorldCupMatch>;
    return (
      typeof item.fixtureId === 'number' &&
      typeof item.round === 'string' &&
      typeof item.kickoffLabel === 'string' &&
      typeof item.kickoffAt === 'string' &&
      typeof item.homeTeam === 'string' &&
      typeof item.awayTeam === 'string' &&
      typeof item.status === 'string'
    );
  }

  private positiveInt(value: string | undefined, fallback: number): number {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }

  private resolveScore(match: Wc2026Match, team: 'home' | 'away'): number | undefined {
    const directScore = team === 'home' ? match.home_score : match.away_score;
    const camelScore = team === 'home' ? match.homeScore : match.awayScore;
    const nestedScore = team === 'home' ? match.score?.home : match.score?.away;
    return directScore ?? camelScore ?? nestedScore;
  }

  private resolveQualifiedPick(match: Wc2026Match): 'home' | 'away' | undefined {
    if (match.qualifiedPick === 'home' || match.qualifiedPick === 'away') {
      return match.qualifiedPick;
    }

    const winner = (match.winner ?? match.winner_team ?? '').trim();
    if (winner.length === 0) return undefined;
    if (this.normalizedTeamName(winner) === this.normalizedTeamName(match.home_team ?? '')) {
      return 'home';
    }
    if (this.normalizedTeamName(winner) === this.normalizedTeamName(match.away_team ?? '')) {
      return 'away';
    }
    return undefined;
  }

  private normalizedTeamName(value: string): string {
    return MatchesService.normalizedStaticTeamName(value);
  }

  private static inferQualifiedPick(
    match: WorldCupMatch,
    matches: WorldCupMatch[],
  ): 'home' | 'away' | undefined {
    const currentRoundRank = MatchesService.knockoutRoundRank(match.round);
    if (currentRoundRank === undefined) return undefined;

    const kickoffAt = new Date(match.kickoffAt).getTime();
    const laterKnockoutMatches = matches.filter((candidate) => {
      const candidateRoundRank = MatchesService.knockoutRoundRank(candidate.round);
      if (
        candidateRoundRank === undefined ||
        candidateRoundRank <= currentRoundRank
      ) {
        return false;
      }

      const candidateKickoffAt = new Date(candidate.kickoffAt).getTime();
      return Number.isNaN(kickoffAt) || candidateKickoffAt > kickoffAt;
    });

    const homeTeam = MatchesService.normalizedStaticTeamName(match.homeTeam);
    const awayTeam = MatchesService.normalizedStaticTeamName(match.awayTeam);
    const homeAppears = laterKnockoutMatches.some((candidate) =>
      MatchesService.matchContainsTeam(candidate, homeTeam),
    );
    const awayAppears = laterKnockoutMatches.some((candidate) =>
      MatchesService.matchContainsTeam(candidate, awayTeam),
    );

    if (homeAppears === awayAppears) return undefined;
    return homeAppears ? 'home' : 'away';
  }

  private static matchContainsTeam(match: WorldCupMatch, team: string): boolean {
    return (
      MatchesService.normalizedStaticTeamName(match.homeTeam) === team ||
      MatchesService.normalizedStaticTeamName(match.awayTeam) === team
    );
  }

  private static isKnockoutRound(round: string): boolean {
    return MatchesService.knockoutRoundRank(round) !== undefined;
  }

  private static knockoutRoundRank(round: string): number | undefined {
    const normalized = round.trim().toUpperCase().replace(/[\s-]+/g, '_');
    if (['RD32', 'R32', 'ROUND_OF_32', '1/16', '16_AVOS'].includes(normalized)) {
      return 1;
    }
    if (['RD16', 'R16', 'ROUND_OF_16', '1/8', 'OITAVAS'].includes(normalized)) {
      return 2;
    }
    if (['QF', 'QUARTER', 'QUARTER_FINAL', 'QUARTER_FINALS', 'QUARTAS'].includes(normalized)) {
      return 3;
    }
    if (['SF', 'SEMI', 'SEMI_FINAL', 'SEMI_FINALS', 'SEMIS'].includes(normalized)) {
      return 4;
    }
    if (['F', 'FINAL'].includes(normalized)) return 5;
    return undefined;
  }

  private static normalizedStaticTeamName(value: string): string {
    return value
      .normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '')
      .trim()
      .toLowerCase();
  }
}

// Types for WC2026 API responses
interface Wc2026Match {
  id?: number;
  match_number?: number;
  round?: string;
  group_name?: string;
  home_team?: string;
  away_team?: string;
  stadium?: string;
  kickoff_utc?: string;
  kickoff?: string;
  status?: string;
  phase?: string;
  home_score?: number;
  away_score?: number;
  homeScore?: number;
  awayScore?: number;
  qualifiedPick?: 'home' | 'away';
  winner?: string;
  winner_team?: string;
  score?: {
    home?: number;
    away?: number;
  };
}

type Wc2026MatchesResponse = Wc2026Match[];
