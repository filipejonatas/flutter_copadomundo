import { Body, Controller, Headers, Post } from '@nestjs/common';
import { AuthService } from '../auth/auth.service';
import {
  AutomationService,
  PlayoffAutomationTickBody,
} from './automation.service';

@Controller('automation')
export class AutomationController {
  constructor(
    private readonly authService: AuthService,
    private readonly automationService: AutomationService,
  ) {}

  @Post('playoff-tick')
  async playoffTick(
    @Headers('x-playoff-admin-secret') adminSecret: string | undefined,
    @Body() body: PlayoffAutomationTickBody,
  ) {
    this.authService.verifyAdminSecretHeader(adminSecret);
    return this.automationService.playoffTick(body);
  }
}
