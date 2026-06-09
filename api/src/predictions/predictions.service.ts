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
  homeScore?: unknown;
  awayScore?: unknown;
}

@Injectable()
export class PredictionsService {
  constructor(
    private readonly firebaseAdmin: FirebaseAdminService,
    private readonly matchesService: MatchesService,
    configService: ConfigService,
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
    const fixtureId = this.validFixtureId(body.fixtureId);
    const pick = this.validPick(body.pick);
    const homeScore = this.validScore(body.homeScore, 'homeScore');
    const awayScore = this.validScore(body.awayScore, 'awayScore');
    const matches = await this.matchesService.getWorldCup2026Matches();
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

    const prediction = {
      fixtureId,
      pick,
      homeScore,
      awayScore,
      round: match.round,
      homeTeam: match.homeTeam,
      awayTeam: match.awayTeam,
      updatedAt: ServerValue.TIMESTAMP,
    };

    await this.firebaseAdmin.database
      .ref(`predictions/${user.uid}/${fixtureId}`)
      .set(prediction);

    return {
      fixtureId,
      pick,
      homeScore,
      awayScore,
      round: match.round,
      homeTeam: match.homeTeam,
      awayTeam: match.awayTeam,
    };
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

  private validScore(value: unknown, field: string): number {
    if (!Number.isInteger(value) || (value as number) < 0 || (value as number) > 9) {
      throw new BadRequestException(`${field} precisa estar entre 0 e 9.`);
    }
    return value as number;
  }

  private isPreMatchStatus(status: string): boolean {
    return ['NS', 'TBD', 'SCHEDULED', 'NOT_STARTED', 'PRE_MATCH'].includes(
      status.trim().toUpperCase(),
    );
  }

  private asRecord(value: unknown): Record<string, UserMatchPrediction> {
    if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
    return value as Record<string, UserMatchPrediction>;
  }

  private positiveInt(value: string | undefined, fallback: number): number {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed >= 0 ? parsed : fallback;
  }
}
