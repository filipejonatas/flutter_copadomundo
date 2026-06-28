import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ServerValue } from 'firebase-admin/database';
import { FirebaseAdminService } from '../firebase-admin.service';
import { LeaderboardService } from '../leaderboard/leaderboard.service';
import { MatchesService } from '../matches/matches.service';
import { WorldCupMatch } from '../matches/world-cup-match';
import {
  MatchPick,
  UserMatchPrediction,
} from '../predictions/predictions.service';
import {
  PlayoffBracket,
  PlayoffMatch,
  PlayoffParticipant,
  PlayoffRoundKey,
  PlayoffRoundScore,
  PlayoffSeedSource,
} from './playoffs.types';

export interface GeneratePlayoffBody {
  deadlineAt?: unknown;
}

@Injectable()
export class PlayoffsService {
  static readonly maxParticipants = 32;
  static readonly bracketSeedOrder = [
    1, 32, 16, 17, 8, 25, 9, 24, 4, 29, 13, 20, 5, 28, 12, 21,
    2, 31, 15, 18, 7, 26, 10, 23, 3, 30, 14, 19, 6, 27, 11, 22,
  ];

  constructor(
    private readonly firebaseAdmin: FirebaseAdminService,
    private readonly leaderboardService: LeaderboardService,
    private readonly matchesService: MatchesService,
    private readonly configService: ConfigService,
  ) {}

  async getCurrentBracket(): Promise<PlayoffBracket | null> {
    const snapshot = await this.firebaseAdmin.database.ref('playoffs/current').get();
    const value = snapshot.val();
    if (!value || typeof value !== 'object') return null;
    return value as PlayoffBracket;
  }

  async generateCurrentBracket(body: GeneratePlayoffBody): Promise<PlayoffBracket> {
    const leaderboard = await this.leaderboardService.loadLeaderboard();
    const bracket = PlayoffsService.generateBracket(
      'current',
      leaderboard,
      this.validOptionalDate(body.deadlineAt),
    );

    await this.firebaseAdmin.database.ref('playoffs/current').set({
      ...bracket,
      updatedAt: ServerValue.TIMESTAMP,
    });

    return bracket;
  }

  async calculateRoundScore(round: string): Promise<PlayoffRoundScore[]> {
    if (!this.isPlayoffActive()) return [];

    const bracket = await this.getCurrentBracket();
    const participantByUserId = new Map(
      (bracket?.participants ?? []).map((participant) => [
        participant.userId,
        participant,
      ]),
    );
    const matches = await this.matchesService.getWorldCup2026Matches();
    const finishedRoundMatches = Object.fromEntries(
      matches
        .filter(
          (match) =>
            match.round === round &&
            this.isPlayoffMatch(match) &&
            this.isFinished(match),
        )
        .map((match) => [String(match.fixtureId), match]),
    );

    const [usersSnapshot, predictionsSnapshot] = await Promise.all([
      this.firebaseAdmin.database.ref('users').get(),
      this.firebaseAdmin.database.ref('predictions').get(),
    ]);

    const users = this.asRecord(usersSnapshot.val());
    const predictions = this.asRecord(predictionsSnapshot.val());
    const userIds = new Set([...Object.keys(users), ...Object.keys(predictions)]);
    const scores: PlayoffRoundScore[] = [];

    for (const userId of userIds) {
      const profile = this.asRecord(users[userId]);
      const userPredictions = this.asPredictions(predictions[userId]);
      const score = this.calculateUserRoundScore(
        userId,
        userPredictions,
        finishedRoundMatches,
      );
      const nick = this.stringValue(profile.nick) ?? 'Palpiteiro';
      const avatarId = this.stringValue(profile.avatarId) ?? 'star';
      const photoUrl = this.stringValue(profile.photoUrl);
      const participant = participantByUserId.get(userId);

      scores.push({
        ...score,
        ...(participant?.seed === undefined ? {} : { seed: participant.seed }),
        nick,
        avatarId,
        ...(photoUrl === undefined ? {} : { photoUrl }),
      });
    }

    return scores.sort((a, b) => {
      if (b.points !== a.points) return b.points - a.points;
      if (a.seed !== undefined && b.seed !== undefined) return a.seed - b.seed;
      if (b.exactScores !== a.exactScores) return b.exactScores - a.exactScores;
      return a.nick.toLowerCase().localeCompare(b.nick.toLowerCase());
    });
  }

  async getCurrentStatus(): Promise<{
    active: boolean;
    startsAt: string;
    serverNow: string;
  }> {
    const now = new Date();
    return {
      active: this.isPlayoffActive(now),
      startsAt: this.playoffStartAt().toISOString(),
      serverNow: now.toISOString(),
    };
  }

  static generateBracket(
    id: string,
    entries: PlayoffSeedSource[],
    deadlineAt?: string,
    generatedAt = new Date().toISOString(),
  ): PlayoffBracket {
    const participants = entries
      .slice(0, PlayoffsService.maxParticipants)
      .map((entry, index) => ({
        userId: entry.userId,
        seed: index + 1,
        nick: entry.nick,
        avatarId: entry.avatarId,
        ...(entry.photoUrl === undefined ? {} : { photoUrl: entry.photoUrl }),
        rankingPoints: entry.points,
      }));
    const participantBySeed = new Map(
      participants.map((participant) => [participant.seed, participant]),
    );
    const matches: PlayoffMatch[] = [];
    const firstRoundMatches: PlayoffMatch[] = [];

    for (let index = 0; index < PlayoffsService.bracketSeedOrder.length; index += 2) {
      const position = index / 2 + 1;
      const participantA = participantBySeed.get(
        PlayoffsService.bracketSeedOrder[index],
      );
      const participantB = participantBySeed.get(
        PlayoffsService.bracketSeedOrder[index + 1],
      );
      const match = PlayoffsService.createMatch(
        'round_of_32',
        0,
        position,
        participantA,
        participantB,
      );
      firstRoundMatches.push(match);
      matches.push(match);
    }

    let previousRound = firstRoundMatches;
    const remainingRounds: PlayoffRoundKey[] = [
      'round_of_16',
      'quarter_final',
      'semi_final',
      'final',
    ];

    remainingRounds.forEach((round, roundOffset) => {
      const nextRound: PlayoffMatch[] = [];
      for (let index = 0; index < previousRound.length; index += 2) {
        const sourceA = previousRound[index];
        const sourceB = previousRound[index + 1];
        const participantA = PlayoffsService.findWinner(
          participants,
          sourceA.winnerParticipantId,
        );
        const participantB = PlayoffsService.findWinner(
          participants,
          sourceB.winnerParticipantId,
        );
        const match = PlayoffsService.createMatch(
          round,
          roundOffset + 1,
          index / 2 + 1,
          participantA,
          participantB,
          sourceA.id,
          sourceB.id,
        );
        nextRound.push(match);
        matches.push(match);
      }
      previousRound = nextRound;
    });

    return {
      id,
      maxParticipants: PlayoffsService.maxParticipants,
      generatedAt,
      ...(deadlineAt === undefined ? {} : { deadlineAt }),
      participants,
      matches,
    };
  }

  static calculatePredictionPoints(
    prediction: UserMatchPrediction,
    match: WorldCupMatch,
  ): number {
    if (match.homeScore === undefined || match.awayScore === undefined) return 0;

    const actualPick =
      match.qualifiedPick ??
      PlayoffsService.pickFromScore(match.homeScore, match.awayScore);
    const predictedQualified = prediction.qualifiedPick ?? prediction.pick;
    if (predictedQualified !== actualPick) return 0;

    const exactScore =
      prediction.homeScore === match.homeScore &&
      prediction.awayScore === match.awayScore;
    if (exactScore) return 10;

    const predictedDifference = prediction.homeScore - prediction.awayScore;
    const actualDifference = match.homeScore - match.awayScore;
    if (predictedDifference === actualDifference) return 7;

    return 5;
  }

  static resolveMatchWinner(
    match: Pick<PlayoffMatch, 'participantA' | 'participantB'>,
    scores: Map<string, Pick<PlayoffRoundScore, 'points'>>,
  ): PlayoffParticipant | undefined {
    if (match.participantA && !match.participantB) return match.participantA;
    if (match.participantB && !match.participantA) return match.participantB;
    if (!match.participantA || !match.participantB) return undefined;

    const pointsA = scores.get(match.participantA.userId)?.points ?? 0;
    const pointsB = scores.get(match.participantB.userId)?.points ?? 0;
    if (pointsA > pointsB) return match.participantA;
    if (pointsB > pointsA) return match.participantB;

    return match.participantA.seed < match.participantB.seed
      ? match.participantA
      : match.participantB;
  }

  private calculateUserRoundScore(
    userId: string,
    predictions: Record<string, UserMatchPrediction>,
    finishedMatches: Record<string, WorldCupMatch>,
  ): Omit<PlayoffRoundScore, 'nick' | 'avatarId' | 'photoUrl'> {
    let points = 0;
    let predictionsCount = 0;
    let exactScores = 0;
    let correctQualified = 0;
    const matchPoints: Record<string, number> = {};

    for (const [fixtureId, prediction] of Object.entries(predictions)) {
      const match = finishedMatches[fixtureId];
      if (!match) continue;

      const scoredPoints = PlayoffsService.calculatePredictionPoints(
        prediction,
        match,
      );
      predictionsCount++;
      points += scoredPoints;
      matchPoints[fixtureId] = scoredPoints;

      if (scoredPoints > 0) correctQualified++;
      if (scoredPoints === 10) exactScores++;
    }

    return {
      userId,
      points,
      predictionsCount,
      exactScores,
      correctQualified,
      matchPoints,
    };
  }

  private static createMatch(
    round: PlayoffRoundKey,
    roundIndex: number,
    position: number,
    participantA?: PlayoffParticipant,
    participantB?: PlayoffParticipant,
    sourceMatchAId?: string,
    sourceMatchBId?: string,
  ): PlayoffMatch {
    const winner =
      participantA && !participantB
        ? participantA
        : participantB && !participantA
          ? participantB
          : undefined;

    return {
      id: `${round}-${position}`,
      round,
      roundIndex,
      position,
      ...(participantA === undefined ? {} : { participantA }),
      ...(participantB === undefined ? {} : { participantB }),
      ...(winner === undefined ? {} : { winnerParticipantId: winner.userId }),
      isBye: winner !== undefined,
      status: winner === undefined ? 'pending' : 'finished',
      ...(sourceMatchAId === undefined ? {} : { sourceMatchAId }),
      ...(sourceMatchBId === undefined ? {} : { sourceMatchBId }),
    };
  }

  private static findWinner(
    participants: PlayoffParticipant[],
    winnerParticipantId?: string,
  ): PlayoffParticipant | undefined {
    if (!winnerParticipantId) return undefined;
    return participants.find((participant) => participant.userId === winnerParticipantId);
  }

  private static pickFromScore(homeScore: number, awayScore: number): MatchPick {
    if (homeScore === awayScore) return 'draw';
    return homeScore > awayScore ? 'home' : 'away';
  }

  private isFinished(match: WorldCupMatch): boolean {
    if (match.homeScore === undefined || match.awayScore === undefined) {
      return false;
    }
    return ['FT', 'FINAL', 'FINISHED', 'AET', 'PEN'].includes(
      match.status.trim().toUpperCase(),
    );
  }

  private isPlayoffMatch(match: WorldCupMatch): boolean {
    return new Date(match.kickoffAt).getTime() >= this.playoffStartAt().getTime();
  }

  private isPlayoffActive(now = new Date()): boolean {
    return now.getTime() >= this.playoffStartAt().getTime();
  }

  private playoffStartAt(): Date {
    const configuredStartAt = this.configService.get<string>('PLAYOFF_START_AT');
    const startAt = configuredStartAt
      ? new Date(configuredStartAt)
      : new Date('2026-06-28T03:00:00.000Z');
    if (Number.isNaN(startAt.getTime())) return new Date('2026-06-28T03:00:00.000Z');
    return startAt;
  }

  private validOptionalDate(value: unknown): string | undefined {
    if (value === undefined || value === null || value === '') return undefined;
    if (typeof value !== 'string') return undefined;
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return undefined;
    return date.toISOString();
  }

  private asRecord(value: unknown): Record<string, unknown> {
    if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
    return value as Record<string, unknown>;
  }

  private asPredictions(value: unknown): Record<string, UserMatchPrediction> {
    if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
    return value as Record<string, UserMatchPrediction>;
  }

  private stringValue(value: unknown): string | undefined {
    if (typeof value !== 'string') return undefined;
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }
}
