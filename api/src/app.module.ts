import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { LeaderboardModule } from './leaderboard/leaderboard.module';
import { MatchesModule } from './matches/matches.module';
import { PlayoffsModule } from './playoffs/playoffs.module';
import { PredictionsModule } from './predictions/predictions.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ['api/.env', '.env'],
    }),
    MatchesModule,
    PredictionsModule,
    LeaderboardModule,
    PlayoffsModule,
  ],
})
export class AppModule {}
