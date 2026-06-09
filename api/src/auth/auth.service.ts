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
      return await this.firebaseAdmin.auth.verifyIdToken(token, true);
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
        consume: options.consume === true,
      })
      .catch(() => {
        throw new UnauthorizedException('Token App Check invalido.');
      });

    if (result.alreadyConsumed) {
      throw new UnauthorizedException('Token App Check invalido.');
    }
  }

  private shouldRequireAppCheck(): boolean {
    const configuredValue = this.configService.get<string>('FIREBASE_APP_CHECK_REQUIRED');
    if (configuredValue) {
      return configuredValue.trim().toLowerCase() !== 'false';
    }

    return this.configService.get<string>('NODE_ENV') === 'production';
  }
}
