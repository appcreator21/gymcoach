import { describe, it, expect } from 'vitest';
import { buildLeaderboard, challengeStatus, publicName, scoreParticipants } from './challenges';

const set = (userId: string, weight: number, reps: number, extra = {}) => ({
  userId,
  weight,
  reps,
  isWarmup: false,
  durationSec: null,
  ...extra,
});

describe('scoreParticipants', () => {
  it('counts finished sessions for WORKOUTS', () => {
    const s = scoreParticipants('WORKOUTS', ['a', 'b'], [{ userId: 'a' }, { userId: 'a' }, { userId: 'b' }, { userId: 'x' }], []);
    expect(s.get('a')).toBe(2);
    expect(s.get('b')).toBe(1);
    expect(s.has('x')).toBe(false);
  });

  it('sums load times reps for VOLUME and skips warm-ups and cardio', () => {
    const s = scoreParticipants('VOLUME', ['a'], [], [
      set('a', 100, 5),
      set('a', 60, 10, { isWarmup: true }),
      set('a', 0, 1, { durationSec: 1200 }),
    ]);
    expect(s.get('a')).toBe(500);
  });

  it('counts working sets for SETS', () => {
    const s = scoreParticipants('SETS', ['a'], [], [set('a', 50, 8), set('a', 50, 8), set('a', 20, 10, { isWarmup: true })]);
    expect(s.get('a')).toBe(2);
  });

  it('gives participants without activity a zero', () => {
    expect(scoreParticipants('VOLUME', ['a'], [], []).get('a')).toBe(0);
  });
});

describe('buildLeaderboard', () => {
  it('ranks high to low and shares ranks on ties', () => {
    const rows = buildLeaderboard(
      new Map([['a', 10], ['b', 20], ['c', 10], ['d', 5]]),
      new Map([['a', 'Ann'], ['b', 'Bo'], ['c', 'Cy'], ['d', 'Di']]),
    );
    expect(rows.map((r) => [r.name, r.rank])).toEqual([['Bo', 1], ['Ann', 2], ['Cy', 2], ['Di', 4]]);
  });
});

describe('publicName', () => {
  it('never exposes more than a first name and last initial', () => {
    expect(publicName('Matthew Huber')).toBe('Matthew H.');
    expect(publicName('Surba')).toBe('Surba');
    expect(publicName(null)).toBe('Athlete');
  });
});

describe('challengeStatus', () => {
  const start = new Date('2026-11-01T00:00:00Z');
  const end = new Date('2026-11-08T00:00:00Z');
  it('reports upcoming, active and ended', () => {
    expect(challengeStatus(start, end, new Date('2026-10-30T00:00:00Z'))).toBe('UPCOMING');
    expect(challengeStatus(start, end, new Date('2026-11-03T00:00:00Z'))).toBe('ACTIVE');
    expect(challengeStatus(start, end, new Date('2026-11-09T00:00:00Z'))).toBe('ENDED');
  });
});
