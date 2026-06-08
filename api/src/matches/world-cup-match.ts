export interface WorldCupMatch {
  fixtureId: number;
  round: string;
  kickoffLabel: string;
  kickoffAt: string;
  homeTeam: string;
  awayTeam: string;
  status: string;
  homeScore?: number;
  awayScore?: number;
}
