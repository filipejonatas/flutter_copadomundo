import { LeaderboardEntry } from '../leaderboard/leaderboard.service';

export type PlayoffRoundKey =
  | 'round_of_32'
  | 'round_of_16'
  | 'quarter_final'
  | 'semi_final'
  | 'final';

export type PlayoffMatchStatus = 'pending' | 'finished';

export interface PlayoffParticipant {
  userId: string;
  seed: number;
  nick: string;
  avatarId: string;
  photoUrl?: string;
  rankingPoints: number;
}

export interface PlayoffMatch {
  id: string;
  round: PlayoffRoundKey;
  roundIndex: number;
  position: number;
  participantA?: PlayoffParticipant;
  participantB?: PlayoffParticipant;
  winnerParticipantId?: string;
  isBye: boolean;
  status: PlayoffMatchStatus;
  sourceMatchAId?: string;
  sourceMatchBId?: string;
}

export interface PlayoffBracket {
  id: string;
  maxParticipants: number;
  generatedAt: string;
  deadlineAt?: string;
  participants: PlayoffParticipant[];
  matches: PlayoffMatch[];
}

export interface PlayoffRoundScore {
  userId: string;
  seed?: number;
  nick: string;
  avatarId: string;
  photoUrl?: string;
  points: number;
  predictionsCount: number;
  exactScores: number;
  correctQualified: number;
  matchPoints: Record<string, number>;
}

export type PlayoffSeedSource = Pick<
  LeaderboardEntry,
  'userId' | 'nick' | 'avatarId' | 'photoUrl' | 'points'
>;
