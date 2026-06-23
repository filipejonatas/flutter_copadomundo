import { Module } from '@nestjs/common';
import { FirebaseAdminService } from '../firebase-admin.service';
import { MatchesController } from './matches.controller';
import { MatchesService } from './matches.service';

@Module({
  controllers: [MatchesController],
  providers: [FirebaseAdminService, MatchesService],
  exports: [MatchesService],
})
export class MatchesModule {}
