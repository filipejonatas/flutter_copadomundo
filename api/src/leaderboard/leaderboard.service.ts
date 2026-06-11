import { Injectable } from '@nestjs/common';
import { ServerValue } from 'firebase-admin/database';
import { FirebaseAdminService } from '../firebase-admin.service';
import { MatchesService } from '../matches/matches.service';
import { WorldCupMatch } from '../matches/world-cup-match';
import {
  MatchPick,
  PredictionsService,
  UserMatchPrediction,
} from '../predictions/predictions.service';

export interface LeaderboardEntry {
  position: number;
  userId: string;
  nick: string;
  avatarId: string;
  photoUrl?: string;
  points: number;
  predictionsCount: number;
  exactScores: number;
}

interface ConsolidatedScore {
  points: number;
  predictionsCount: number;
  hits: number;
  exactScores: number;
  matches: Record<string, Record<string, unknown>>;
}

@Injectable()
export class LeaderboardService {
  constructor(
    private readonly firebaseAdmin: FirebaseAdminService,
    private readonly matchesService: MatchesService,
    private readonly predictionsService: PredictionsService,
  ) {}

  static readonly pointsPerExactScore = 5;
  static readonly pointsPerCorrectPick = 3;

  async loadLeaderboard(): Promise<LeaderboardEntry[]> {
    const matches = await this.matchesService.getWorldCup2026Matches();
    const finishedMatches = Object.fromEntries(
      matches
        .filter((match) => this.isFinished(match))
        .map((match) => [String(match.fixtureId), match]),
    );
    const [usersSnapshot, predictionsSnapshot] = await Promise.all([
      this.firebaseAdmin.database.ref('users').get(),
      this.firebaseAdmin.database.ref('predictions').get(),
    ]);
    const users = this.asRecord(usersSnapshot.val());
    const predictions = this.asRecord(predictionsSnapshot.val());
    const userIds = new Set([...Object.keys(users), ...Object.keys(predictions)]);
    const entries: LeaderboardEntry[] = [];

    for (const userId of userIds) {
      const profile = this.asRecord(users[userId]);
      const userPredictions = this.asPredictions(predictions[userId]);
      const score = this.calculateScore(userPredictions, finishedMatches);
      const nick = this.stringValue(profile.nick) ?? 'Palpiteiro';
      const avatarId = this.stringValue(profile.avatarId) ?? 'star';
      const photoUrl = this.stringValue(profile.photoUrl);

      await this.persistScore(userId, nick, avatarId, photoUrl, score);

      entries.push({
        position: 0,
        userId,
        nick,
        avatarId,
        photoUrl,
        points: score.points,
        predictionsCount: score.predictionsCount,
        exactScores: score.exactScores,
      });
    }

    entries.sort((a, b) => {
      if (b.points !== a.points) return b.points - a.points;
      if (b.predictionsCount !== a.predictionsCount) {
        return b.predictionsCount - a.predictionsCount;
      }
      return a.nick.toLowerCase().localeCompare(b.nick.toLowerCase());
    });

    return entries.map((entry, index) => ({
      ...entry,
      position: index + 1,
    }));
  }

  private calculateScore(
    predictions: Record<string, UserMatchPrediction>,
    finishedMatches: Record<string, WorldCupMatch>,
  ): ConsolidatedScore {
    let points = 0;
    let predictionsCount = 0;
    let hits = 0;
    let exactScores = 0;
    const matchScores: Record<string, Record<string, unknown>> = {};

    for (const [fixtureId, prediction] of Object.entries(predictions)) {
      const match = finishedMatches[fixtureId];
      if (!match || match.homeScore === undefined || match.awayScore === undefined) {
        continue;
      }

      const actualPick = this.predictionsService.pickFromScore(
        match.homeScore,
        match.awayScore,
      );
      const correctPick = prediction.pick === actualPick;
      const exactScore =
        correctPick &&
        prediction.homeScore === match.homeScore &&
        prediction.awayScore === match.awayScore;
      const matchPoints = exactScore
        ? LeaderboardService.pointsPerExactScore
        : correctPick
          ? LeaderboardService.pointsPerCorrectPick
          : 0;

      predictionsCount++;
      points += matchPoints;
      if (correctPick) hits++;
      if (exactScore) exactScores++;

      matchScores[fixtureId] = {
        fixtureId: match.fixtureId,
        pick: prediction.pick,
        result: actualPick,
        homeScore: match.homeScore,
        awayScore: match.awayScore,
        predictedHomeScore: prediction.homeScore,
        predictedAwayScore: prediction.awayScore,
        points: matchPoints,
        exactScore,
      };
    }

    return {
      points,
      predictionsCount,
      hits,
      exactScores,
      matches: matchScores,
    };
  }

  private isFinished(match: WorldCupMatch): boolean {
    if (match.homeScore === undefined || match.awayScore === undefined) {
      return false;
    }
    return ['FT', 'FINAL', 'FINISHED', 'AET', 'PEN'].includes(
      match.status.trim().toUpperCase(),
    );
  }

  private persistScore(
    userId: string,
    nick: string,
    avatarId: string,
    photoUrl: string | undefined,
    score: ConsolidatedScore,
  ) {
    return this.firebaseAdmin.database.ref(`scores/${userId}`).set({
      userId,
      nick,
      avatarId,
      photoUrl,
      points: score.points,
      predictionsCount: score.predictionsCount,
      hits: score.hits,
      exactScores: score.exactScores,
      matches: score.matches,
      updatedAt: ServerValue.TIMESTAMP,
    });
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
