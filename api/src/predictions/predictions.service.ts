import { BadRequestException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DecodedIdToken } from 'firebase-admin/auth';
import { ServerValue } from 'firebase-admin/database';
import { WorldCupMatch } from '../matches/world-cup-match';
import { MatchesService } from '../matches/matches.service';
import { FirebaseAdminService } from '../firebase-admin.service';

export type MatchPick = 'home' | 'draw' | 'away';

export interface UserMatchPrediction {
  fixtureId: number;
  pick: MatchPick;
  qualifiedPick?: Exclude<MatchPick, 'draw'>;
  homeScore: number;
  awayScore: number;
  round?: string;
  homeTeam?: string;
  awayTeam?: string;
  updatedAt?: number;
}

export interface SavePredictionBody {
  fixtureId?: unknown;
  pick?: unknown;
  qualifiedPick?: unknown;
  homeScore?: unknown;
  awayScore?: unknown;
}

export interface SavePredictionsBulkBody {
  predictions?: unknown;
}

export interface MatchPredictionResult {
  userId: string;
  nick: string;
  avatarId: string;
  photoUrl?: string;
  pick: MatchPick;
  qualifiedPick?: Exclude<MatchPick, 'draw'>;
  predictedHomeScore: number;
  predictedAwayScore: number;
  points: number;
  exactScore: boolean;
  correctPick: boolean;
}

export interface MatchPredictionResultsResponse {
  fixtureId: number;
  round: string;
  homeTeam: string;
  awayTeam: string;
  status: string;
  homeScore: number;
  awayScore: number;
  qualifiedPick?: Exclude<MatchPick, 'draw'>;
  predictions: MatchPredictionResult[];
}

@Injectable()
export class PredictionsService {
  static readonly groupPointsPerExactScore = 5;
  static readonly groupPointsPerCorrectPick = 3;
  static readonly playoffPointsPerExactScore = 10;
  static readonly playoffPointsPerCorrectDifference = 7;
  static readonly playoffPointsPerQualified = 5;

  constructor(
    private readonly firebaseAdmin: FirebaseAdminService,
    private readonly matchesService: MatchesService,
    private readonly configService: ConfigService,
  ) {
    this.cutoffBufferMs =
      this.positiveInt(configService.get<string>('PREDICTION_CUTOFF_BUFFER_SECONDS'), 60) *
      1000;
  }

  private readonly cutoffBufferMs: number;

  async getUserPredictions(uid: string): Promise<Record<string, UserMatchPrediction>> {
    const snapshot = await this.firebaseAdmin.database
      .ref(`predictions/${uid}`)
      .get();
    return this.asRecord(snapshot.val());
  }

  async savePrediction(
    user: DecodedIdToken,
    body: SavePredictionBody,
  ): Promise<UserMatchPrediction> {
    const matches = await this.matchesService.getWorldCup2026Matches();
    const prediction = this.buildPrediction(body, matches);

    await this.firebaseAdmin.database
      .ref(`predictions/${user.uid}/${prediction.fixtureId}`)
      .set({ ...prediction, updatedAt: ServerValue.TIMESTAMP });

    return prediction;
  }

  async savePredictionsBulk(
    user: DecodedIdToken,
    body: SavePredictionsBulkBody,
  ): Promise<UserMatchPrediction[]> {
    if (!Array.isArray(body.predictions)) {
      throw new BadRequestException('predictions precisa ser uma lista.');
    }
    if (body.predictions.length === 0) return [];
    if (body.predictions.length > 128) {
      throw new BadRequestException('Envie no maximo 128 palpites por vez.');
    }

    const matches = await this.matchesService.getWorldCup2026Matches();
    const predictions = body.predictions.map((item) =>
      this.buildPrediction(item as SavePredictionBody, matches),
    );
    const updates = Object.fromEntries(
      predictions.map((prediction) => [
        String(prediction.fixtureId),
        { ...prediction, updatedAt: ServerValue.TIMESTAMP },
      ]),
    );

    await this.firebaseAdmin.database.ref(`predictions/${user.uid}`).update(updates);
    return predictions;
  }

  async getMatchPredictionResults(
    fixtureId: number,
  ): Promise<MatchPredictionResultsResponse> {
    const matches = await this.matchesService.getWorldCup2026Matches();
    const match = matches.find((item) => item.fixtureId === fixtureId);
    if (!match) {
      throw new BadRequestException('Jogo nao encontrado.');
    }
    if (!this.isFinished(match) || match.homeScore === undefined || match.awayScore === undefined) {
      throw new BadRequestException('Palpites ficam disponiveis apenas apos o fim do jogo.');
    }

    const [usersSnapshot, predictionsSnapshot] = await Promise.all([
      this.firebaseAdmin.database.ref('users').get(),
      this.firebaseAdmin.database.ref('predictions').get(),
    ]);
    const users = this.asUnknownRecord(usersSnapshot.val());
    const predictionsByUser = this.asUnknownRecord(predictionsSnapshot.val());
    const results: MatchPredictionResult[] = [];

    for (const [userId, rawPredictions] of Object.entries(predictionsByUser)) {
      const prediction = this.asRecord(rawPredictions)[String(fixtureId)];
      if (!prediction) continue;
      const userPrediction = prediction as UserMatchPrediction;
      if (
        !Number.isInteger(userPrediction.homeScore) ||
        !Number.isInteger(userPrediction.awayScore)
      ) {
        continue;
      }

      const profile = this.asUnknownRecord(users[userId]);
      const score = this.calculatePredictionScore(userPrediction, match);
      results.push({
        userId,
        nick: this.stringValue(profile.nick) ?? 'Palpiteiro',
        avatarId: this.stringValue(profile.avatarId) ?? 'star',
        ...(this.stringValue(profile.photoUrl) === undefined
          ? {}
          : { photoUrl: this.stringValue(profile.photoUrl) }),
        pick: userPrediction.pick,
        ...(userPrediction.qualifiedPick === undefined
          ? {}
          : { qualifiedPick: userPrediction.qualifiedPick }),
        predictedHomeScore: userPrediction.homeScore,
        predictedAwayScore: userPrediction.awayScore,
        points: score.points,
        exactScore: score.exactScore,
        correctPick: score.correctPick,
      });
    }

    results.sort((a, b) => {
      if (b.points !== a.points) return b.points - a.points;
      if (b.exactScore !== a.exactScore) return b.exactScore ? 1 : -1;
      return a.nick.toLowerCase().localeCompare(b.nick.toLowerCase());
    });

    return {
      fixtureId: match.fixtureId,
      round: match.round,
      homeTeam: match.homeTeam,
      awayTeam: match.awayTeam,
      status: match.status,
      homeScore: match.homeScore,
      awayScore: match.awayScore,
      ...(match.qualifiedPick === undefined ? {} : { qualifiedPick: match.qualifiedPick }),
      predictions: results,
    };
  }

  calculatePredictionScore(
    prediction: UserMatchPrediction,
    match: WorldCupMatch,
  ): { points: number; exactScore: boolean; correctPick: boolean } {
    if (match.homeScore === undefined || match.awayScore === undefined) {
      return { points: 0, exactScore: false, correctPick: false };
    }

    if (this.isPlayoffMatch(match)) {
      return this.calculatePlayoffPredictionScore(prediction, match);
    }

    const actualPick = this.pickFromScore(match.homeScore, match.awayScore);
    const correctPick = prediction.pick === actualPick;
    const exactScore =
      correctPick &&
      prediction.homeScore === match.homeScore &&
      prediction.awayScore === match.awayScore;
    const points = exactScore
      ? PredictionsService.groupPointsPerExactScore
      : correctPick
        ? PredictionsService.groupPointsPerCorrectPick
        : 0;

    return { points, exactScore, correctPick };
  }

  private buildPrediction(
    body: SavePredictionBody,
    matches: WorldCupMatch[],
  ): UserMatchPrediction {
    const fixtureId = this.validFixtureId(body.fixtureId);
    const pick = this.validPick(body.pick);
    const qualifiedPick = this.validQualifiedPick(body.qualifiedPick);
    const homeScore = this.validScore(body.homeScore, 'homeScore');
    const awayScore = this.validScore(body.awayScore, 'awayScore');
    const match = matches.find((item) => item.fixtureId === fixtureId);

    if (!match) {
      throw new BadRequestException('Jogo nao encontrado.');
    }
    if (!this.isPredictionOpen(match)) {
      throw new BadRequestException('Palpites para este jogo ja estao encerrados.');
    }
    if (pick !== this.pickFromScore(homeScore, awayScore)) {
      throw new BadRequestException('Palpite nao confere com o placar informado.');
    }
    if (qualifiedPick && pick !== 'draw' && qualifiedPick !== pick) {
      throw new BadRequestException('Classificado nao confere com o placar informado.');
    }

    const prediction = {
      fixtureId,
      pick,
      ...(qualifiedPick === undefined ? {} : { qualifiedPick }),
      homeScore,
      awayScore,
      round: match.round,
      homeTeam: match.homeTeam,
      awayTeam: match.awayTeam,
    };
    return prediction;
  }

  isPredictionOpen(match: WorldCupMatch, now = new Date()): boolean {
    const kickoff = new Date(match.kickoffAt);
    if (Number.isNaN(kickoff.getTime())) return false;
    if (!this.isPreMatchStatus(match.status)) return false;
    return now.getTime() < kickoff.getTime() - this.cutoffBufferMs;
  }

  pickFromScore(homeScore: number, awayScore: number): MatchPick {
    if (homeScore === awayScore) return 'draw';
    return homeScore > awayScore ? 'home' : 'away';
  }

  validFixtureId(value: unknown): number {
    if (typeof value !== 'number' || !Number.isInteger(value) || value <= 0) {
      throw new BadRequestException('fixtureId invalido.');
    }
    return value;
  }

  private validPick(value: unknown): MatchPick {
    if (value === 'home' || value === 'draw' || value === 'away') return value;
    throw new BadRequestException('pick invalido.');
  }

  private validQualifiedPick(value: unknown): Exclude<MatchPick, 'draw'> | undefined {
    if (value === undefined || value === null || value === '') return undefined;
    if (value === 'home' || value === 'away') return value;
    throw new BadRequestException('qualifiedPick invalido.');
  }

  private validScore(value: unknown, field: string): number {
    if (!Number.isInteger(value) || (value as number) < 0 || (value as number) > 9) {
      throw new BadRequestException(`${field} precisa estar entre 0 e 9.`);
    }
    return value as number;
  }

  private isPreMatchStatus(status: string): boolean {
    return ['NS', 'PRE', 'TBD', 'SCHEDULED', 'NOT_STARTED', 'PRE_MATCH'].includes(
      status.trim().toUpperCase(),
    );
  }

  private calculatePlayoffPredictionScore(
    prediction: UserMatchPrediction,
    match: WorldCupMatch,
  ): { points: number; exactScore: boolean; correctPick: boolean } {
    if (match.homeScore === undefined || match.awayScore === undefined) {
      return { points: 0, exactScore: false, correctPick: false };
    }

    const actualPick =
      match.qualifiedPick ?? this.pickFromScore(match.homeScore, match.awayScore);
    const predictedQualified = prediction.qualifiedPick ?? prediction.pick;
    const correctPick = predictedQualified === actualPick;
    if (!correctPick) return { points: 0, exactScore: false, correctPick: false };

    const exactScore =
      prediction.homeScore === match.homeScore &&
      prediction.awayScore === match.awayScore;
    if (exactScore) {
      return {
        points: PredictionsService.playoffPointsPerExactScore,
        exactScore,
        correctPick,
      };
    }

    const predictedDifference = prediction.homeScore - prediction.awayScore;
    const actualDifference = match.homeScore - match.awayScore;
    if (predictedDifference === actualDifference) {
      return {
        points: PredictionsService.playoffPointsPerCorrectDifference,
        exactScore,
        correctPick,
      };
    }

    return {
      points: PredictionsService.playoffPointsPerQualified,
      exactScore,
      correctPick,
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

  private isPlayoffMatch(match: WorldCupMatch): boolean {
    return new Date(match.kickoffAt).getTime() >= this.playoffStartAt().getTime();
  }

  private playoffStartAt(): Date {
    const configuredStartAt = this.configService.get<string>('PLAYOFF_START_AT');
    const startAt = configuredStartAt
      ? new Date(configuredStartAt)
      : new Date('2026-06-29T03:00:00.000Z');
    if (Number.isNaN(startAt.getTime())) return new Date('2026-06-29T03:00:00.000Z');
    return startAt;
  }

  private asRecord(value: unknown): Record<string, UserMatchPrediction> {
    if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
    return value as Record<string, UserMatchPrediction>;
  }

  private asUnknownRecord(value: unknown): Record<string, unknown> {
    if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
    return value as Record<string, unknown>;
  }

  private stringValue(value: unknown): string | undefined {
    if (typeof value !== 'string') return undefined;
    const trimmed = value.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  }

  private positiveInt(value: string | undefined, fallback: number): number {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed >= 0 ? parsed : fallback;
  }
}
