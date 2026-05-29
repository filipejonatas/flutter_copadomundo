import { Controller, Get } from '@nestjs/common';
import { MatchesService } from './matches.service';
import { WorldCupMatch } from './world-cup-match';

@Controller('matches')
export class MatchesController {
  constructor(private readonly matchesService: MatchesService) {}

  @Get('world-cup-2026')
  getWorldCup2026Matches(): WorldCupMatch[] {
    return this.matchesService.getWorldCup2026Matches();
  }
}
