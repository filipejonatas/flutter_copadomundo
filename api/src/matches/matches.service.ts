import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { WorldCupMatch } from './world-cup-match';

@Injectable()
export class MatchesService {
  constructor(private readonly configService: ConfigService) {}

  async getWorldCup2026Matches(): Promise<WorldCupMatch[]> {
    const wcKey = this.configService.get<string>('WC2026_API_KEY');
    const fallbackKey = this.configService.get<string>('API_FOOTBALL_KEY');
    const hasWcKey = this.hasConfiguredKey(wcKey);
    const hasApiFootballKey = this.hasConfiguredKey(fallbackKey);

    if (!hasWcKey && !hasApiFootballKey) {
      return this.getMockWorldCup2026Matches();
    }

    if (hasWcKey) {
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
          const kickoff =
            m.kickoff_utc ?? m.kickoff ?? new Date().toISOString();
          return {
            fixtureId: m.id ?? m.match_number ?? 0,
            round: (m.round ?? '') + (m.group_name ? ` - ${m.group_name}` : ''),
            kickoffLabel: this.formatKickoffLabel(kickoff),
            kickoffAt: kickoff,
            homeTeam: m.home_team ?? '',
            awayTeam: m.away_team ?? '',
            status: m.phase ?? m.status ?? '',
          } as WorldCupMatch;
        }),
      );
    }

    const baseUrl =
      this.configService.get<string>('API_FOOTBALL_BASE_URL') ??
      'https://v3.football.api-sports.io';
    const url = new URL('/fixtures', baseUrl);
    url.searchParams.set('league', '1');
    url.searchParams.set('season', '2026');

    const response = await fetch(url, {
      headers: {
        'x-apisports-key': this.normalizeKey(fallbackKey),
      },
    });

    if (!response.ok) {
      throw new Error(`API-Football respondeu status ${response.status}`);
    }

    const payload = (await response.json()) as ApiFootballFixturesResponse;
    if (this.hasApiFootballErrors(payload.errors)) {
      throw new Error('API-Football retornou erros na consulta de jogos.');
    }

    if (payload.response.length === 0) {
      return this.getMockWorldCup2026Matches();
    }

    return this.sortByKickoff(
      payload.response.map((fixture) => ({
        fixtureId: fixture.fixture.id,
        round: fixture.league.round,
        kickoffLabel: this.formatKickoffLabel(fixture.fixture.date),
        kickoffAt: fixture.fixture.date,
        homeTeam: fixture.teams.home.name,
        awayTeam: fixture.teams.away.name,
        status: fixture.fixture.status.short,
      })),
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
        status: 'NS',
      },
      {
        fixtureId: 2026002,
        round: 'Group Stage - 1',
        kickoffLabel: '12 jun, 19:00',
        kickoffAt: '2026-06-12T22:00:00Z',
        homeTeam: 'Canada',
        awayTeam: 'Japan',
        status: 'NS',
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

  private hasApiFootballErrors(errors?: Record<string, unknown> | unknown[]): boolean {
    if (!errors) return false;
    if (Array.isArray(errors)) return errors.length > 0;
    return Object.keys(errors).length > 0;
  }

  private sortByKickoff(matches: WorldCupMatch[]): WorldCupMatch[] {
    return [...matches].sort(
      (a, b) =>
        new Date(a.kickoffAt).getTime() - new Date(b.kickoffAt).getTime(),
    );
  }
}

interface ApiFootballFixturesResponse {
  errors?: Record<string, unknown> | unknown[];
  response: ApiFootballFixture[];
}

interface ApiFootballFixture {
  fixture: {
    id: number;
    date: string;
    status: {
      short: string;
    };
  };
  league: {
    round: string;
  };
  teams: {
    home: {
      name: string;
    };
    away: {
      name: string;
    };
  };
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
}

type Wc2026MatchesResponse = Wc2026Match[];
