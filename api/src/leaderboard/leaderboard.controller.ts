import { Controller, Get, Headers, Post } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { LeaderboardService } from './leaderboard.service';

@Controller('leaderboard')
export class LeaderboardController {
  constructor(
    private readonly authService: AuthService,
    private readonly leaderboardService: LeaderboardService,
  ) {}

  @Get()
  async getLeaderboard(
    @Headers('authorization') authorization?: string,
    @Headers('x-firebase-appcheck') appCheckToken?: string,
  ) {
    await this.authService.verifyAppCheckHeader(appCheckToken);
    await this.authService.verifyAuthorizationHeader(authorization);
    return this.leaderboardService.loadLeaderboard();
  }

  @Post('recalculate')
  async recalculateLeaderboard(
    @Headers('x-playoff-admin-secret') adminSecret?: string,
  ) {
    this.authService.verifyAdminSecretHeader(adminSecret);
    return this.leaderboardService.recalculateLeaderboard();
  }
}
