import { describe, expect, it } from 'vitest';
import { buildInitialMemory, MEMORY_MAX_CHARS } from '@/lib/memory';
import { onboardingSchema } from '@/lib/schemas/onboarding';

const base = {
  displayName: 'Sam',
  goal: 'HYPERTROPHY',
  experience: 'SOME',
  daysPerWeek: 4,
  sessionMinutes: 60,
  location: 'COMMERCIAL_GYM',
};

describe('onboardingSchema', () => {
  it('applies defaults and accepts a minimal answer set', () => {
    const parsed = onboardingSchema.parse(base);
    expect(parsed.unit).toBe('KG');
    expect(parsed.focusAreas).toEqual([]);
    expect(parsed.coachingStyle).toBe('SUPPORTIVE');
  });

  it('rejects out-of-range values', () => {
    expect(onboardingSchema.safeParse({ ...base, daysPerWeek: 9 }).success).toBe(false);
    expect(onboardingSchema.safeParse({ ...base, displayName: ' ' }).success).toBe(false);
  });
});

describe('buildInitialMemory', () => {
  it('renders the answers as a markdown memory file', () => {
    const memory = buildInitialMemory(
      onboardingSchema.parse({ ...base, injuries: 'Left shoulder impingement', focusAreas: ['Back'] }),
    );
    expect(memory).toContain('# Sam');
    expect(memory).toContain('Main goal: Build muscle');
    expect(memory).toContain('4 days per week, about 60 minutes');
    expect(memory).toContain('Left shoulder impingement');
    expect(memory).toContain('Wants extra focus on: Back');
  });

  it('records no injuries explicitly and stays under the cap', () => {
    const memory = buildInitialMemory(
      onboardingSchema.parse({ ...base, motivation: 'x'.repeat(300), dislikes: 'y'.repeat(300) }),
    );
    expect(memory).toContain('none reported');
    expect(memory.length).toBeLessThanOrEqual(MEMORY_MAX_CHARS);
  });
});
