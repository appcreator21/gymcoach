import { describe, it, expect } from 'vitest';
import { sessionStartSchema, sessionUpdateSchema } from './session';

describe('sessionStartSchema', () => {
  it('requires a non-empty workoutId', () => {
    expect(sessionStartSchema.parse({ workoutId: 'w1' }).workoutId).toBe('w1');
    expect(sessionStartSchema.safeParse({ workoutId: '' }).success).toBe(false);
    expect(sessionStartSchema.safeParse({}).success).toBe(false);
  });
});

describe('sessionUpdateSchema', () => {
  it('accepts an empty object (all fields optional)', () => {
    expect(sessionUpdateSchema.safeParse({}).success).toBe(true);
  });

  it('trims notes and accepts a finish flag', () => {
    const parsed = sessionUpdateSchema.parse({ notes: '  good session  ', finish: true });
    expect(parsed.notes).toBe('good session');
    expect(parsed.finish).toBe(true);
  });

  it('rejects notes longer than 2000 characters', () => {
    expect(sessionUpdateSchema.safeParse({ notes: 'x'.repeat(2001) }).success).toBe(false);
  });
});

describe('sessionUpdateSchema actions', () => {
  it('accepts a single action', () => {
    expect(sessionUpdateSchema.safeParse({ pause: true }).success).toBe(true);
    expect(sessionUpdateSchema.safeParse({ reopen: true, notes: 'x' }).success).toBe(true);
  });

  it('rejects two actions in one request', () => {
    expect(sessionUpdateSchema.safeParse({ pause: true, finish: true }).success).toBe(false);
  });

  it('treats false flags as no action', () => {
    expect(sessionUpdateSchema.safeParse({ pause: false, finish: false }).success).toBe(true);
  });
});
