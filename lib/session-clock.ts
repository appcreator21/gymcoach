// The clock of a workout session: pause, resume, finish and reopen, and the
// active (non-paused) duration. Pure, so it is unit tested; the session route
// applies the result.

export interface ClockState {
  startedAt: Date;
  finishedAt: Date | null;
  pausedAt: Date | null;
  pausedSec: number;
}

export type ClockAction = 'pause' | 'resume' | 'finish' | 'reopen';

export interface ClockUpdate {
  finishedAt: Date | null;
  pausedAt: Date | null;
  pausedSec: number;
}

export class ClockError extends Error {}

function secondsBetween(from: Date, to: Date): number {
  return Math.max(0, Math.round((to.getTime() - from.getTime()) / 1000));
}

// Every action is idempotent: repeating it (a retried request, a double tap)
// leaves the state as the first call left it.
export function applyClockAction(s: ClockState, action: ClockAction, now: Date): ClockUpdate {
  const same: ClockUpdate = { finishedAt: s.finishedAt, pausedAt: s.pausedAt, pausedSec: s.pausedSec };
  switch (action) {
    case 'pause':
      if (s.finishedAt) throw new ClockError('Session already finished.');
      if (s.pausedAt) return same;
      return { ...same, pausedAt: now };
    case 'resume':
      if (s.finishedAt) throw new ClockError('Session already finished.');
      if (!s.pausedAt) return same;
      return { ...same, pausedAt: null, pausedSec: s.pausedSec + secondsBetween(s.pausedAt, now) };
    case 'finish':
      if (s.finishedAt) return same;
      // Finishing while paused ends the pause now, so the paused time is not
      // counted as training time.
      return {
        finishedAt: now,
        pausedAt: null,
        pausedSec: s.pausedAt ? s.pausedSec + secondsBetween(s.pausedAt, now) : s.pausedSec,
      };
    case 'reopen':
      if (!s.finishedAt) return same;
      // A reopened workout comes back paused as of the moment it finished, so
      // the time it sat finished is not training time either.
      return { finishedAt: null, pausedAt: s.finishedAt, pausedSec: s.pausedSec };
  }
}

// Seconds of real training: elapsed time minus every pause, past and ongoing.
export function activeSeconds(s: ClockState, now: Date): number {
  const end = s.finishedAt ?? now;
  const elapsed = secondsBetween(s.startedAt, end);
  const ongoingPause = s.pausedAt && !s.finishedAt ? secondsBetween(s.pausedAt, now) : 0;
  return Math.max(0, elapsed - s.pausedSec - ongoingPause);
}
