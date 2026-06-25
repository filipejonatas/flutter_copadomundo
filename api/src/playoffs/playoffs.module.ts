import { Module } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import { FirebaseAdminService } from '../firebase-admin.service';
import { LeaderboardModule } from '../leaderboard/leaderboard.module';
import { MatchesModule } from '../matches/matches.module';
import { PlayoffsController } from './playoffs.controller';
import { PlayoffsService } from './playoffs.service';

@Module({
  imports: [LeaderboardModule, MatchesModule],
  controllers: [PlayoffsController],
  providers: [AuthService, FirebaseAdminService, PlayoffsService],
})
export class PlayoffsModule {}

