import { Body, Controller, Get, Headers, Post } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { PredictionsService, SavePredictionBody } from './predictions.service';

@Controller('predictions')
export class PredictionsController {
  constructor(
    private readonly authService: AuthService,
    private readonly predictionsService: PredictionsService,
  ) {}

  @Get('me')
  async getMyPredictions(@Headers('authorization') authorization?: string) {
    const user = await this.authService.verifyAuthorizationHeader(authorization);
    return this.predictionsService.getUserPredictions(user.uid);
  }

  @Post()
  async savePrediction(
    @Headers('authorization') authorization: string | undefined,
    @Body() body: SavePredictionBody,
  ) {
    const user = await this.authService.verifyAuthorizationHeader(authorization);
    return this.predictionsService.savePrediction(user, body);
  }
}
