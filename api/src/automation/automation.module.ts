import { Module } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { FirebaseAdminService } from '../firebase-admin.service';
import { LeaderboardModule } from '../leaderboard/leaderboard.module';
import { MatchesModule } from '../matches/matches.module';
import { PlayoffsModule } from '../playoffs/playoffs.module';
import { AutomationController } from './automation.controller';
import { AutomationService } from './automation.service';

@Module({
  imports: [LeaderboardModule, MatchesModule, PlayoffsModule],
  controllers: [AutomationController],
  providers: [AuthService, FirebaseAdminService, AutomationService],
})
export class AutomationModule {}
