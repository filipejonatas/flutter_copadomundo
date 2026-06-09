import { Module } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { FirebaseAdminService } from '../firebase-admin.service';
import { MatchesModule } from '../matches/matches.module';
import { PredictionsController } from './predictions.controller';
import { PredictionRateLimitService } from './prediction-rate-limit.service';
import { PredictionsService } from './predictions.service';

@Module({
  imports: [MatchesModule],
  controllers: [PredictionsController],
  providers: [
    AuthService,
    FirebaseAdminService,
    PredictionRateLimitService,
    PredictionsService,
  ],
  exports: [PredictionsService],
})
export class PredictionsModule {}
