import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { MatchesModule } from './matches/matches.module';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
    }),
    MatchesModule,
  ],
})
export class AppModule {}
