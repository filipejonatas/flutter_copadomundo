import { Injectable, UnauthorizedException } from '@nestjs/common';
import { DecodedIdToken } from 'firebase-admin/auth';
import { FirebaseAdminService } from '../firebase-admin.service';

@Injectable()
export class AuthService {
  constructor(private readonly firebaseAdmin: FirebaseAdminService) {}

  async verifyAuthorizationHeader(
    authorization?: string,
  ): Promise<DecodedIdToken> {
    const [scheme, token] = authorization?.split(' ') ?? [];
    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException('Token Firebase ausente.');
    }

    try {
      return await this.firebaseAdmin.auth.verifyIdToken(token);
    } catch {
      throw new UnauthorizedException('Token Firebase invalido.');
    }
  }
}
