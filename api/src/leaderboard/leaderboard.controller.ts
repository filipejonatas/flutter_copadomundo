import { Controller, Get, Headers } from '@nestjs/common';
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
}
