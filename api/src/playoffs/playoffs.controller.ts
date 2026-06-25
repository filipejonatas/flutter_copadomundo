import { Body, Controller, Get, Headers, Post, Query } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import {
  GeneratePlayoffBody,
  PlayoffsService,
} from './playoffs.service';

@Controller('playoffs')
export class PlayoffsController {
  constructor(
    private readonly authService: AuthService,
    private readonly playoffsService: PlayoffsService,
  ) {}

  @Get('current')
  async getCurrent(
    @Headers('authorization') authorization?: string,
    @Headers('x-firebase-appcheck') appCheckToken?: string,
  ) {
    await this.authService.verifyAppCheckHeader(appCheckToken);
    await this.authService.verifyAuthorizationHeader(authorization);
    return this.playoffsService.getCurrentBracket();
  }

  @Get('current/status')
  async getCurrentStatus(
    @Headers('authorization') authorization?: string,
    @Headers('x-firebase-appcheck') appCheckToken?: string,
  ) {
    await this.authService.verifyAppCheckHeader(appCheckToken);
    await this.authService.verifyAuthorizationHeader(authorization);
    return this.playoffsService.getCurrentStatus();
  }

  @Post('current/generate-bracket')
  async generateCurrentBracket(
    @Headers('authorization') authorization: string | undefined,
    @Headers('x-firebase-appcheck') appCheckToken: string | undefined,
    @Body() body: GeneratePlayoffBody,
  ) {
    await this.authService.verifyAppCheckHeader(appCheckToken);
    await this.authService.verifyAuthorizationHeader(authorization);
    return this.playoffsService.generateCurrentBracket(body);
  }

  @Get('current/round-score')
  async getRoundScore(
    @Headers('authorization') authorization: string | undefined,
    @Headers('x-firebase-appcheck') appCheckToken: string | undefined,
    @Query('round') round?: string,
  ) {
    await this.authService.verifyAppCheckHeader(appCheckToken);
    await this.authService.verifyAuthorizationHeader(authorization);
    return this.playoffsService.calculateRoundScore(round ?? '');
  }
}
