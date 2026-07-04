import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DecodedIdToken } from 'firebase-admin/auth';
import { FirebaseAdminService } from '../firebase-admin.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly firebaseAdmin: FirebaseAdminService,
    private readonly configService: ConfigService,
  ) {}

  async verifyAuthorizationHeader(
    authorization?: string,
  ): Promise<DecodedIdToken> {
    const [scheme, token] = authorization?.split(' ') ?? [];
    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException('Token Firebase ausente.');
    }

    try {
      return await this.firebaseAdmin.auth.verifyIdToken(
        token,
        this.shouldCheckRevokedTokens(),
      );
    } catch {
      throw new UnauthorizedException('Token Firebase invalido.');
    }
  }

  async verifyAppCheckHeader(
    appCheckToken?: string,
    options: { consume?: boolean } = {},
  ): Promise<void> {
    if (!this.shouldRequireAppCheck()) return;

    if (!appCheckToken) {
      throw new UnauthorizedException('Token App Check ausente.');
    }

    const result = await this.firebaseAdmin.appCheck
      .verifyToken(appCheckToken, {
        consume: options.consume === true && this.shouldConsumeAppCheckTokens(),
      })
      .catch(() => {
        throw new UnauthorizedException('Token App Check invalido.');
      });

    if (result.alreadyConsumed) {
      throw new UnauthorizedException('Token App Check ja consumido.');
    }
  }

  verifyAdminSecretHeader(secret?: string): void {
    const configuredSecret = this.configService
      .get<string>('PLAYOFF_ADMIN_SECRET')
      ?.trim();
    if (!configuredSecret || secret !== configuredSecret) {
      throw new UnauthorizedException('Segredo administrativo invalido.');
    }
  }

  private shouldRequireAppCheck(): boolean {
    const configuredValue = this.configService.get<string>('FIREBASE_APP_CHECK_REQUIRED');
    if (configuredValue) {
      return configuredValue.trim().toLowerCase() !== 'false';
    }

    return this.configService.get<string>('NODE_ENV') === 'production';
  }

  private shouldCheckRevokedTokens(): boolean {
    const configuredValue = this.configService.get<string>('FIREBASE_AUTH_CHECK_REVOKED');
    if (configuredValue) {
      return configuredValue.trim().toLowerCase() !== 'false';
    }

    return this.configService.get<string>('NODE_ENV') === 'production';
  }

  private shouldConsumeAppCheckTokens(): boolean {
    const configuredValue = this.configService.get<string>(
      'FIREBASE_APP_CHECK_CONSUME_TOKENS',
    );
    if (configuredValue) {
      return configuredValue.trim().toLowerCase() === 'true';
    }

    return false;
  }
}
