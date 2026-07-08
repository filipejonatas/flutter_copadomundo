import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ServerValue } from 'firebase-admin/database';
import { FirebaseAdminService } from '../firebase-admin.service';
import { LeaderboardService } from '../leaderboard/leaderboard.service';
import { MatchesService } from '../matches/matches.service';
import { WorldCupMatch } from '../matches/world-cup-match';
import { PlayoffsService } from '../playoffs/playoffs.service';

export interface PlayoffAutomationTickBody {
  force?: unknown;
  minRefreshMinutes?: unknown;
}

export interface PlayoffAutomationTickResult {
  status: 'skipped' | 'checked' | 'processed';
  reason?: string;
  minRefreshMinutes: number;
  previousRefreshAt?: number;
  refreshedAt?: number;
  matchesCount?: number;
  finishedFixturesCount?: number;
  newFinishedFixtures: string[];
  leaderboardRecalculated: boolean;
  bracketAdvanced: boolean;
  currentRound?: string;
  nextRound?: string;
  runId?: string;
}

interface AutomationState {
  lastMatchesRefreshAt?: number;
  processedFinishedFixtures?: Record<string, boolean>;
}

@Injectable()
export class AutomationService {
  private readonly logger = new Logger(AutomationService.name);
  private readonly statePath = 'automation/playoffTick/state';
  private readonly runsPath = 'automation/playoffTick/runs';

  constructor(
    private readonly firebaseAdmin: FirebaseAdminService,
    private readonly leaderboardService: LeaderboardService,
    private readonly matchesService: MatchesService,
    private readonly playoffsService: PlayoffsService,
    private readonly configService: ConfigService,
  ) {}

  async playoffTick(
    body: PlayoffAutomationTickBody = {},
  ): Promise<PlayoffAutomationTickResult> {
    const now = Date.now();
    const force = body.force === true;
    const minRefreshMinutes = this.minRefreshMinutes(body.minRefreshMinutes);
    const state = await this.loadState();
    const previousRefreshAt = this.numberValue(state.lastMatchesRefreshAt);

    if (
      !force &&
      previousRefreshAt !== undefined &&
      now - previousRefreshAt < minRefreshMinutes * 60_000
    ) {
      const result: PlayoffAutomationTickResult = {
        status: 'skipped',
        reason: 'minimum-refresh-window',
        minRefreshMinutes,
        previousRefreshAt,
        newFinishedFixtures: [],
        leaderboardRecalculated: false,
        bracketAdvanced: false,
      };
      await this.saveRun(result);
      return result;
    }

    const matches = await this.matchesService.refreshWorldCup2026Matches();
    const refreshedAt = Date.now();
    const finishedFixtures = matches.filter((match) => this.isFinished(match));
    const processedFinishedFixtures = {
      ...(state.processedFinishedFixtures ?? {}),
    };
    const newFinishedFixtures = finishedFixtures
      .map((match) => String(match.fixtureId))
      .filter((fixtureId) => !processedFinishedFixtures[fixtureId]);

    let leaderboardRecalculated = false;
    if (newFinishedFixtures.length > 0) {
      await this.leaderboardService.recalculateLeaderboard();
      leaderboardRecalculated = true;
      for (const fixtureId of newFinishedFixtures) {
        processedFinishedFixtures[fixtureId] = true;
      }
    }

    let bracketAdvanced = false;
    let currentRound: string | undefined;
    let nextRound: string | undefined;
    const bracket = await this.playoffsService.getCurrentBracket();
    currentRound = this.playoffsService.getCurrentPendingRound(bracket);

    if (
      currentRound !== undefined &&
      this.playoffsService.isRoundCompleteWithMatches(currentRound, matches)
    ) {
      const advancedBracket = await this.playoffsService.advanceCurrentRound({
        round: currentRound,
      }, matches);
      bracketAdvanced = true;
      nextRound = this.playoffsService.getCurrentPendingRound(advancedBracket);
    }

    await this.firebaseAdmin.database.ref(this.statePath).set({
      lastMatchesRefreshAt: refreshedAt,
      processedFinishedFixtures,
      updatedAt: ServerValue.TIMESTAMP,
    });

    const result: PlayoffAutomationTickResult = {
      status:
        newFinishedFixtures.length > 0 || bracketAdvanced
          ? 'processed'
          : 'checked',
      minRefreshMinutes,
      ...(previousRefreshAt === undefined ? {} : { previousRefreshAt }),
      refreshedAt,
      matchesCount: matches.length,
      finishedFixturesCount: finishedFixtures.length,
      newFinishedFixtures,
      leaderboardRecalculated,
      bracketAdvanced,
      ...(currentRound === undefined ? {} : { currentRound }),
      ...(nextRound === undefined ? {} : { nextRound }),
    };
    const runId = await this.saveRun(result);
    this.logger.log(
      `Automation tick ${result.status}: ${newFinishedFixtures.length} new fixture(s), bracketAdvanced=${bracketAdvanced}`,
    );
    return { ...result, runId };
  }

  private async loadState(): Promise<AutomationState> {
    const snapshot = await this.firebaseAdmin.database.ref(this.statePath).get();
    const value = snapshot.val();
    if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
    const record = value as Record<string, unknown>;
    return {
      lastMatchesRefreshAt: this.numberValue(record.lastMatchesRefreshAt),
      processedFinishedFixtures: this.booleanRecord(
        record.processedFinishedFixtures,
      ),
    };
  }

  private async saveRun(result: PlayoffAutomationTickResult): Promise<string> {
    const ref = this.firebaseAdmin.database.ref(this.runsPath).push();
    await ref.set({
      ...result,
      createdAt: ServerValue.TIMESTAMP,
    });
    return ref.key ?? String(Date.now());
  }

  private minRefreshMinutes(value: unknown): number {
    if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
      return Math.max(5, Math.floor(value));
    }

    const configured = Number(
      this.configService.get<string>('AUTOMATION_MIN_REFRESH_MINUTES') ?? '25',
    );
    if (Number.isFinite(configured) && configured > 0) {
      return Math.max(5, Math.floor(configured));
    }

    return 25;
  }

  private booleanRecord(value: unknown): Record<string, boolean> {
    if (!value || typeof value !== 'object') return {};
    return Object.fromEntries(
      Object.entries(value as Record<string, unknown>)
        .filter(([, item]) => item === true)
        .map(([key]) => [key, true]),
    );
  }

  private numberValue(value: unknown): number | undefined {
    return typeof value === 'number' && Number.isFinite(value)
      ? value
      : undefined;
  }

  private isFinished(match: WorldCupMatch): boolean {
    if (match.homeScore === undefined || match.awayScore === undefined) {
      return false;
    }
    return ['FT', 'FINAL', 'FINISHED', 'AET', 'PEN'].includes(
      match.status.trim().toUpperCase(),
    );
  }
}
