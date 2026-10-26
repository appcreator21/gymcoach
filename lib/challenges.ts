// Scoring and display helpers for challenges. Pure, so they are unit tested;
// the routes feed them rows read from the database.

export type ChallengeMetric = 'WORKOUTS' | 'SETS' | 'VOLUME';

export interface ScoredSet {
  userId: string;
  weight: number;
  reps: number;
  isWarmup: boolean;
  durationSec: number | null;
}

export interface ScoredSession {
  userId: string;
}

export interface LeaderboardRow {
  userId: string;
  name: string;
  score: number;
  rank: number;
}

// Score per participant for one metric. Warm-ups and cardio sets never count
// toward sets or volume; WORKOUTS counts finished sessions.
export function scoreParticipants(
  metric: ChallengeMetric,
  participantIds: string[],
  sessions: ScoredSession[],
  sets: ScoredSet[],
): Map<string, number> {
  const scores = new Map<string, number>(participantIds.map((id) => [id, 0]));
  if (metric === 'WORKOUTS') {
    for (const s of sessions) {
      if (scores.has(s.userId)) scores.set(s.userId, (scores.get(s.userId) ?? 0) + 1);
    }
    return scores;
  }
  for (const set of sets) {
    if (!scores.has(set.userId) || set.isWarmup || set.durationSec != null) continue;
    const add = metric === 'SETS' ? 1 : set.weight * set.reps;
    scores.set(set.userId, (scores.get(set.userId) ?? 0) + add);
  }
  return scores;
}

// Competition ranking: equal scores share a rank (1, 2, 2, 4).
export function buildLeaderboard(
  scores: Map<string, number>,
  names: Map<string, string>,
): LeaderboardRow[] {
  const rows = [...scores.entries()]
    .map(([userId, score]) => ({
      userId,
      name: names.get(userId) ?? 'Athlete',
      score: Math.round(score * 10) / 10,
    }))
    .sort((a, b) => b.score - a.score || a.name.localeCompare(b.name));
  let lastScore = Number.NaN;
  let lastRank = 0;
  return rows.map((row, index) => {
    const rank = row.score === lastScore ? lastRank : index + 1;
    lastScore = row.score;
    lastRank = rank;
    return { ...row, rank };
  });
}

// A short public name: first name plus last initial, never the email.
export function publicName(displayName: string | null | undefined): string {
  const parts = (displayName ?? '').trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return 'Athlete';
  if (parts.length === 1) return parts[0]!;
  return `${parts[0]} ${parts[parts.length - 1]!.charAt(0).toUpperCase()}.`;
}

export function challengeStatus(startsAt: Date, endsAt: Date, now = new Date()): 'UPCOMING' | 'ACTIVE' | 'ENDED' {
  if (now < startsAt) return 'UPCOMING';
  if (now > endsAt) return 'ENDED';
  return 'ACTIVE';
}
