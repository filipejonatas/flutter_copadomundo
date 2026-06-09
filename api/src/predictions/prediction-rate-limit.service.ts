import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface Bucket {
  count: number;
  resetAt: number;
}

@Injectable()
export class PredictionRateLimitService {
  private readonly buckets = new Map<string, Bucket>();
  private readonly ipLimit: number;
  private readonly userLimit: number;
  private readonly fixtureLimit: number;
  private readonly windowMs: number;
  private readonly fixtureWindowMs: number;

  constructor(configService: ConfigService) {
    this.ipLimit = this.positiveInt(configService.get<string>('PREDICTION_IP_RATE_LIMIT'), 60);
    this.userLimit = this.positiveInt(configService.get<string>('PREDICTION_USER_RATE_LIMIT'), 20);
    this.fixtureLimit = this.positiveInt(
      configService.get<string>('PREDICTION_FIXTURE_RATE_LIMIT'),
      5,
    );
    this.windowMs =
      this.positiveInt(configService.get<string>('PREDICTION_RATE_WINDOW_SECONDS'), 60) *
      1000;
    this.fixtureWindowMs =
      this.positiveInt(
        configService.get<string>('PREDICTION_FIXTURE_RATE_WINDOW_SECONDS'),
        10,
      ) * 1000;
  }

  checkIp(ip: string): void {
    this.consume(`ip:${ip || 'unknown'}`, this.ipLimit, this.windowMs);
  }

  checkUser(uid: string, ip: string, fixtureId: number): void {
    this.consume(`user:${uid}`, this.userLimit, this.windowMs);
    this.consume(`fixture:${uid}:${fixtureId}`, this.fixtureLimit, this.fixtureWindowMs);
    this.consume(`ip-fixture:${ip || 'unknown'}:${fixtureId}`, this.fixtureLimit, this.fixtureWindowMs);
  }

  private consume(key: string, limit: number, windowMs: number): void {
    const now = Date.now();
    const bucket = this.buckets.get(key);

    if (!bucket || bucket.resetAt <= now) {
      this.buckets.set(key, { count: 1, resetAt: now + windowMs });
      this.pruneExpired(now);
      return;
    }

    if (bucket.count >= limit) {
      throw new HttpException(
        'Muitas tentativas. Aguarde e tente novamente.',
        HttpStatus.TOO_MANY_REQUESTS,
      );
    }

    bucket.count++;
  }

  private pruneExpired(now: number): void {
    if (this.buckets.size < 1000) return;

    for (const [key, bucket] of this.buckets.entries()) {
      if (bucket.resetAt <= now) {
        this.buckets.delete(key);
      }
    }
  }

  private positiveInt(value: string | undefined, fallback: number): number {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
