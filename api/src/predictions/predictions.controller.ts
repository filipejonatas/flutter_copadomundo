import { Body, Controller, Get, Headers, Ip, Post } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { PredictionRateLimitService } from './prediction-rate-limit.service';
import { PredictionsService, SavePredictionBody } from './predictions.service';

@Controller('predictions')
export class PredictionsController {
  constructor(
    private readonly authService: AuthService,
    private readonly predictionRateLimit: PredictionRateLimitService,
    private readonly predictionsService: PredictionsService,
  ) {}

  @Get('me')
  async getMyPredictions(
    @Headers('authorization') authorization?: string,
    @Headers('x-firebase-appcheck') appCheckToken?: string,
  ) {
    await this.authService.verifyAppCheckHeader(appCheckToken);
    const user = await this.authService.verifyAuthorizationHeader(authorization);
    return this.predictionsService.getUserPredictions(user.uid);
  }

  @Post()
  async savePrediction(
    @Headers('authorization') authorization: string | undefined,
    @Headers('x-firebase-appcheck') appCheckToken: string | undefined,
    @Body() body: SavePredictionBody,
    @Ip() ip: string,
  ) {
    this.predictionRateLimit.checkIp(ip);
    await this.authService.verifyAppCheckHeader(appCheckToken, { consume: true });
    const user = await this.authService.verifyAuthorizationHeader(authorization);
    const fixtureId = this.predictionsService.validFixtureId(body.fixtureId);
    this.predictionRateLimit.checkUser(user.uid, ip, fixtureId);
    return this.predictionsService.savePrediction(user, body);
  }
}
