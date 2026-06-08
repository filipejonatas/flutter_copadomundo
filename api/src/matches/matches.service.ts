import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { WorldCupMatch } from './world-cup-match';

@Injectable()
export class MatchesService {
  constructor(private readonly configService: ConfigService) {}

  async getWorldCup2026Matches(): Promise<WorldCupMatch[]> {
    const wcKey = this.configService.get<string>('WC2026_API_KEY');
    const hasWcKey = this.hasConfiguredKey(wcKey);

    if (!hasWcKey) {
      return this.getMockWorldCup2026Matches();
    }

    const configuredWcKey = this.normalizeKey(wcKey);
    const baseUrl =
      this.configService.get<string>('WC2026_BASE_URL') ??
      'https://api.wc2026api.com';
    const url = new URL('/matches', baseUrl);

    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${configuredWcKey}`,
      },
    });

    if (!response.ok) {
      throw new Error(`WC2026 API respondeu status ${response.status}`);
    }

    const payload = (await response.json()) as Wc2026MatchesResponse;
    if (!Array.isArray(payload)) {
      return this.getMockWorldCup2026Matches();
    }

    return this.sortByKickoff(
      payload.map((m) => {
        const kickoff = m.kickoff_utc ?? m.kickoff ?? new Date().toISOString();
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
        } as WorldCupMatch;
      }),
    );
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
    return (value ?? '').trim().replace(/^['"]|['"]$/g, '');
  }

  private sortByKickoff(matches: WorldCupMatch[]): WorldCupMatch[] {
    return [...matches].sort(
      (a, b) =>
        new Date(a.kickoffAt).getTime() - new Date(b.kickoffAt).getTime(),
    );
  }

  private resolveScore(match: Wc2026Match, team: 'home' | 'away'): number | undefined {
    const directScore = team === 'home' ? match.home_score : match.away_score;
    const camelScore = team === 'home' ? match.homeScore : match.awayScore;
    const nestedScore = team === 'home' ? match.score?.home : match.score?.away;
    return directScore ?? camelScore ?? nestedScore;
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
  score?: {
    home?: number;
    away?: number;
  };
}

type Wc2026MatchesResponse = Wc2026Match[];
