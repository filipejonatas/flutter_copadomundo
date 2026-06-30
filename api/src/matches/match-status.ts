import { WorldCupMatch } from './world-cup-match';

const finishedStatuses = new Set([
  'FT',
  'FINAL',
  'FINISHED',
  'AET',
  'PEN',
  'FT_PEN',
]);

export function isFinishedMatch(match: WorldCupMatch): boolean {
  if (match.homeScore === undefined || match.awayScore === undefined) {
    return false;
  }
  return finishedStatuses.has(match.status.trim().toUpperCase());
}
