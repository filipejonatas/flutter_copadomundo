import { test } from 'node:test';
import * as assert from 'node:assert/strict';
import { PlayoffsService } from './playoffs.service';
import { PlayoffSeedSource } from './playoffs.types';
import { UserMatchPrediction } from '../predictions/predictions.service';
import { WorldCupMatch } from '../matches/world-cup-match';
import { MatchesService } from '../matches/matches.service';

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

test('calculatePredictionPoints increases points for semi, third place, and final', () => {
  const phaseMatch = (round: string): WorldCupMatch => ({
    ...finishedMatch,
    round,
  });

  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(2, 1, 'home'),
      phaseMatch('Semi Final'),
    ),
    20,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(1, 0, 'home'),
      phaseMatch('Semi Final'),
    ),
    14,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(3, 1, 'home'),
      phaseMatch('Semi Final'),
    ),
    10,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(2, 1, 'home'),
      phaseMatch('Third Place'),
    ),
    25,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(1, 0, 'home'),
      phaseMatch('Third Place'),
    ),
    18,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(3, 1, 'home'),
      phaseMatch('Third Place'),
    ),
    13,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(2, 1, 'home'),
      phaseMatch('Final'),
    ),
    30,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(1, 0, 'home'),
      phaseMatch('Final'),
    ),
    21,
  );
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      prediction(3, 1, 'home'),
      phaseMatch('Final'),
    ),
    15,
  );
});

test('withInferredQualifiedPicks derives tied knockout winner from next round', () => {
  const matches = MatchesService.withInferredQualifiedPicks([
    {
      fixtureId: 78,
      round: 'R32',
      kickoffLabel: '03 jul, 15:00',
      kickoffAt: '2026-07-03T18:00:00Z',
      homeTeam: 'Australia',
      awayTeam: 'Egypt',
      status: 'FT',
      homeScore: 1,
      awayScore: 1,
    },
    {
      fixtureId: 103,
      round: 'R16',
      kickoffLabel: '07 jul, 13:00',
      kickoffAt: '2026-07-07T16:00:00Z',
      homeTeam: 'Argentina',
      awayTeam: 'Egypt',
      status: 'PRE',
    },
  ]);
  const australiaEgypt = matches.find((match) => match.fixtureId === 78);

  assert.equal(australiaEgypt?.qualifiedPick, 'away');
  assert.equal(
    PlayoffsService.calculatePredictionPoints(
      {
        fixtureId: 78,
        pick: 'draw',
        qualifiedPick: 'away',
        homeScore: 1,
        awayScore: 1,
      },
      australiaEgypt as WorldCupMatch,
    ),
    10,
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
