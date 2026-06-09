import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getDatabase } from 'firebase-admin/database';

@Injectable()
export class FirebaseAdminService {
  constructor(private readonly configService: ConfigService) {
    if (getApps().length === 0) {
      initializeApp({
        credential: this.resolveCredential(),
        databaseURL:
          this.configService.get<string>('FIREBASE_DATABASE_URL') ??
          'https://copa-palpite-default-rtdb.firebaseio.com',
        projectId:
          this.configService.get<string>('FIREBASE_PROJECT_ID') ??
          'copa-palpite',
      });
    }
  }

  get auth() {
    return getAuth();
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
}
