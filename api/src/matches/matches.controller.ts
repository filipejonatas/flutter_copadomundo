import { Controller, Get, Logger } from '@nestjs/common';
import { MatchesService } from './matches.service';
import { WorldCupMatch } from './world-cup-match';

@Controller('matches')
export class MatchesController {
  private static worldCupMatchesRequestCount = 0;
  private readonly logger = new Logger(MatchesController.name);

  constructor(private readonly matchesService: MatchesService) {}

  @Get('world-cup-2026')
  getWorldCup2026Matches(): Promise<WorldCupMatch[]> {
    MatchesController.worldCupMatchesRequestCount++;
    this.logger.log(
      `GET /matches/world-cup-2026 request count: ${MatchesController.worldCupMatchesRequestCount}`,
    );
    return this.matchesService.getWorldCup2026Matches();
  }
}
