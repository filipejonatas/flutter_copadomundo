import { Injectable } from '@nestjs/common';
import { WorldCupMatch } from './world-cup-match';

@Injectable()
export class MatchesService {
  getWorldCup2026Matches(): WorldCupMatch[] {
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
}
