import { describe, it, expect } from 'vitest';
import { activeSeconds, applyClockAction, ClockError, type ClockState } from './session-clock';

const t = (min: number) => new Date(Date.UTC(2026, 9, 29, 10, min, 0));
const fresh: ClockState = { startedAt: t(0), finishedAt: null, pausedAt: null, pausedSec: 0 };

describe('applyClockAction', () => {
  it('pauses and resumes, adding the pause to pausedSec', () => {
    const paused = { ...fresh, ...applyClockAction(fresh, 'pause', t(10)) };
    expect(paused.pausedAt).toEqual(t(10));
    const resumed = { ...paused, ...applyClockAction(paused, 'resume', t(25)) };
    expect(resumed.pausedAt).toBeNull();
    expect(resumed.pausedSec).toBe(15 * 60);
  });

  it('is idempotent', () => {
    const paused = { ...fresh, ...applyClockAction(fresh, 'pause', t(10)) };
    expect(applyClockAction(paused, 'pause', t(20)).pausedAt).toEqual(t(10));
    expect(applyClockAction(fresh, 'resume', t(20)).pausedSec).toBe(0);
    const done = { ...fresh, ...applyClockAction(fresh, 'finish', t(30)) };
    expect(applyClockAction(done, 'finish', t(50)).finishedAt).toEqual(t(30));
  });

  it('refuses to pause or resume a finished session', () => {
    const done = { ...fresh, ...applyClockAction(fresh, 'finish', t(30)) };
    expect(() => applyClockAction(done, 'pause', t(31))).toThrow(ClockError);
    expect(() => applyClockAction(done, 'resume', t(31))).toThrow(ClockError);
  });

  it('does not count a pause that is still open when finishing', () => {
    const paused = { ...fresh, ...applyClockAction(fresh, 'pause', t(20)) };
    const done = { ...paused, ...applyClockAction(paused, 'finish', t(50)) };
    expect(done.pausedAt).toBeNull();
    expect(activeSeconds(done, t(90))).toBe(20 * 60);
  });

  it('reopen then finish leaves the active time unchanged', () => {
    const done = { ...fresh, ...applyClockAction(fresh, 'finish', t(40)) };
    const reopened = { ...done, ...applyClockAction(done, 'reopen', t(100)) };
    expect(reopened.finishedAt).toBeNull();
    expect(reopened.pausedAt).toEqual(t(40));
    const again = { ...reopened, ...applyClockAction(reopened, 'finish', t(105)) };
    expect(activeSeconds(again, t(200))).toBe(40 * 60);
  });

  it('reopen then resume counts only the time after resuming', () => {
    const done = { ...fresh, ...applyClockAction(fresh, 'finish', t(40)) };
    const reopened = { ...done, ...applyClockAction(done, 'reopen', t(100)) };
    const resumed = { ...reopened, ...applyClockAction(reopened, 'resume', t(100)) };
    expect(activeSeconds(resumed, t(110))).toBe(50 * 60);
  });
});

describe('activeSeconds', () => {
  it('excludes past and ongoing pauses', () => {
    const s: ClockState = { startedAt: t(0), finishedAt: null, pausedAt: t(40), pausedSec: 5 * 60 };
    expect(activeSeconds(s, t(60))).toBe((60 - 5 - 20) * 60);
  });

  it('never goes negative', () => {
    expect(activeSeconds({ ...fresh, pausedSec: 99999 }, t(1))).toBe(0);
  });
});
