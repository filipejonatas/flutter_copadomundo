import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAppCheck } from 'firebase-admin/app-check';
import { getAuth } from 'firebase-admin/auth';
import { getDatabase } from 'firebase-admin/database';

@Injectable()
export class FirebaseAdminService {
  constructor(private readonly configService: ConfigService) {
    if (getApps().length === 0) {
      const databaseURL = this.requiredConfig(
        'FIREBASE_DATABASE_URL',
        'https://copa-palpite-default-rtdb.firebaseio.com',
      );
      const projectId = this.requiredConfig('FIREBASE_PROJECT_ID', 'copa-palpite');

      initializeApp({
        credential: this.resolveCredential(),
        databaseURL,
        projectId,
      });
    }
  }

  get auth() {
    return getAuth();
  }

  get appCheck() {
    return getAppCheck();
  }

  get database() {
    return getDatabase();
  }

  private resolveCredential() {
    const serviceAccountBase64 = this.configService.get<string>(
      'FIREBASE_SERVICE_ACCOUNT_BASE64',
    );
    if (serviceAccountBase64) {
      return cert(
        JSON.parse(Buffer.from(serviceAccountBase64, 'base64').toString('utf8')),
      );
    }

    const serviceAccountJson = this.configService.get<string>(
      'FIREBASE_SERVICE_ACCOUNT',
    );
    if (serviceAccountJson) {
      return cert(JSON.parse(serviceAccountJson));
    }

    return applicationDefault();
  }

  private requiredConfig(key: string, developmentFallback: string): string {
    const value = this.configService.get<string>(key)?.trim();
    if (value) return value;

    if (this.configService.get<string>('NODE_ENV') === 'production') {
      throw new Error(`${key} precisa estar configurada em producao.`);
    }

    return developmentFallback;
  }
}
