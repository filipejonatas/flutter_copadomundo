import { test } from 'node:test';
import * as assert from 'node:assert/strict';
import { PlayoffsService } from './playoffs.service';
import { PlayoffSeedSource } from './playoffs.types';
import { UserMatchPrediction } from '../predictions/predictions.service';
import { WorldCupMatch } from '../matches/world-cup-match';
import { isFinishedMatch } from '../matches/match-status';

function prediction(
  homeScore: number,
  awayScore: number,
  pick: UserMatchPrediction['pick'],
): UserMatchPrediction {
  return {
    fixtureId: 1,
    pick,
    homeScore,
    awayScore,
  };
}

const finishedMatch: WorldCupMatch = {
  fixtureId: 1,
  round: 'Round of 32',
  kickoffLabel: '01 jul, 16:00',
  kickoffAt: '2026-07-01T19:00:00Z',
  homeTeam: 'Brazil',
  awayTeam: 'France',
  status: 'FT',
  homeScore: 2,
  awayScore: 1,
};

test('calculatePredictionPoints scores playoff predictions as 0, 5, 7, or 10', () => {
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(1, 2, 'away'),
      finishedMatch,
    ),
    0,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(1, 0, 'home'),
      finishedMatch,
    ),
    7,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(3, 1, 'home'),
      finishedMatch,
    ),
    5,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(2, 1, 'home'),
      finishedMatch,
    ),
    10,
  );
});

test('calculatePredictionPoints accepts qualifiedPick for tied knockout guesses', () => {
  const tiedPrediction: UserMatchPrediction = {
    ...prediction(1, 1, 'draw'),
    qualifiedPick: 'home',
  };
  const penaltyMatch: WorldCupMatch = {
    ...finishedMatch,
    homeScore: 1,
    awayScore: 1,
    status: 'PEN',
    qualifiedPick: 'home',
  };

  assert.equal(
    PlayoffsService.calculatePredictionPoints(tiedPrediction, penaltyMatch),
    10,
  );
});

test('calculatePredictionPoints accepts FT_PEN penalty shootout status', () => {
  const tiedPrediction: UserMatchPrediction = {
    ...prediction(1, 1, 'draw'),
    qualifiedPick: 'away',
  };
  const penaltyMatch: WorldCupMatch = {
    ...finishedMatch,
    homeScore: 1,
    awayScore: 1,
    status: 'FT_PEN',
    qualifiedPick: 'away',
  };

  assert.equal(
    PlayoffsService.calculatePredictionPoints(tiedPrediction, penaltyMatch),
    10,
  );
});

test('calculatePredictionPoints derives penalty winner from penalty score', () => {
  const exactPrediction: UserMatchPrediction = {
    ...prediction(1, 1, 'draw'),
    qualifiedPick: 'away',
  };
  const sameDifferencePrediction: UserMatchPrediction = {
    ...prediction(2, 2, 'draw'),
    qualifiedPick: 'away',
  };
  const penaltyMatch: WorldCupMatch = {
    ...finishedMatch,
    homeTeam: 'Netherlands',
    awayTeam: 'Morocco',
    homeScore: 1,
    awayScore: 1,
    homePenaltyScore: 2,
    awayPenaltyScore: 3,
    status: 'FT_PEN',
  };

  assert.equal(
    PlayoffsService.calculatePredictionPoints(exactPrediction, penaltyMatch),
    10,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      sameDifferencePrediction,
      penaltyMatch,
    ),
    7,
  );
});

test('isFinishedMatch treats FT_PEN matches with scores as finished', () => {
  assert.equal(
    isFinishedMatch({
      ...finishedMatch,
      status: 'FT_PEN',
      homeScore: 1,
      awayScore: 1,
    }),
    true,
  );
});

test('generateBracket creates a 32-player bracket without byes', () => {
  const bracket = PlayoffsService.generateBracket(
    'current',
    seedEntries(32),
    undefined,
    '2026-06-25T03:00:00.000Z',
  );

  assert.equal(bracket.participants.length, 32);
  assert.equal(bracket.matches.length, 31);
  assert.equal(
    bracket.matches.filter((match) => match.round === 'round_of_32').length,
    16,
  );
  assert.equal(bracket.matches.some((match) => match.isBye), false);
});

test('generateBracket gives four byes to top seeds with 28 players', () => {
  const bracket = PlayoffsService.generateBracket(
    'current',
    seedEntries(28),
    undefined,
    '2026-06-25T03:00:00.000Z',
  );
  const byeMatches = bracket.matches.filter(
    (match) => match.round === 'round_of_32' && match.isBye,
  );

  assert.equal(bracket.participants.length, 28);
  assert.equal(byeMatches.length, 4);
  assert.deepEqual(
    byeMatches.map((match) => match.winnerParticipantId).sort(),
    ['user-1', 'user-2', 'user-3', 'user-4'],
  );
});

test('resolveMatchWinner advances the higher seed when player points tie', () => {
  const bracket = PlayoffsService.generateBracket(
    'current',
    seedEntries(32),
    undefined,
    '2026-06-25T03:00:00.000Z',
  );
  const match = bracket.matches.find(
    (item) =>
      item.participantA?.userId === 'user-16' &&
      item.participantB?.userId === 'user-17',
  );

  assert.ok(match);
  assert.equal(
    PlayoffsService.resolveMatchWinner(
      match,
      new Map([
        ['user-16', { points: 12 }],
        ['user-17', { points: 12 }],
      ]),
    )?.userId,
    'user-16',
  );
});

function seedEntries(total: number): PlayoffSeedSource[] {
  return Array.from({ length: total }, (_, index) => ({
    userId: `user-${index + 1}`,
    nick: `User ${index + 1}`,
    avatarId: 'star',
    points: total - index,
  }));
}
