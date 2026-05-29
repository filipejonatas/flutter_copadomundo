import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { WorldCupMatch } from './world-cup-match';

@Injectable()
export class MatchesService {
  constructor(private readonly configService: ConfigService) {}

  async getWorldCup2026Matches(): Promise<WorldCupMatch[]> {
    const apiKey = this.configService.get<string>('API_FOOTBALL_KEY');

    if (!apiKey || apiKey === 'coloque_sua_chave_aqui') {
      return this.getMockWorldCup2026Matches();
    }

    const baseUrl =
      this.configService.get<string>('API_FOOTBALL_BASE_URL') ??
      'https://v3.football.api-sports.io';
    const url = new URL('/fixtures', baseUrl);
    url.searchParams.set('league', '1');
    url.searchParams.set('season', '2026');

    const response = await fetch(url, {
      headers: {
        'x-apisports-key': apiKey,
      },
    });

    if (!response.ok) {
      throw new Error(`API-Football respondeu status ${response.status}`);
    }

    const payload = (await response.json()) as ApiFootballFixturesResponse;
    if (payload.errors && Object.keys(payload.errors).length > 0) {
      return this.getMockWorldCup2026Matches();
    }

    if (payload.response.length === 0) {
      return this.getMockWorldCup2026Matches();
    }

    return payload.response.map((fixture) => ({
      fixtureId: fixture.fixture.id,
      round: fixture.league.round,
      kickoffLabel: this.formatKickoffLabel(fixture.fixture.date),
      kickoffAt: fixture.fixture.date,
      homeTeam: fixture.teams.home.name,
      awayTeam: fixture.teams.away.name,
      status: fixture.fixture.status.short,
    }));
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
}

interface ApiFootballFixturesResponse {
  errors?: Record<string, unknown>;
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
