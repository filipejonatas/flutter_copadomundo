import { Module } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { FirebaseAdminService } from '../firebase-admin.service';
import { MatchesModule } from '../matches/matches.module';
import { PredictionsModule } from '../predictions/predictions.module';
import { LeaderboardController } from './leaderboard.controller';
import { LeaderboardService } from './leaderboard.service';

@Module({
  imports: [MatchesModule, PredictionsModule],
  controllers: [LeaderboardController],
  providers: [AuthService, FirebaseAdminService, LeaderboardService],
  exports: [LeaderboardService],
})
export class LeaderboardModule {}
