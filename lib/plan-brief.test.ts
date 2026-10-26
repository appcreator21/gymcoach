import { describe, it, expect } from 'vitest';
import { buildPlanGoal, buildQuickWorkoutGoal, expectedExerciseRange } from './plan-brief';
import { planRequestSchema, quickWorkoutRequestSchema } from './schemas/plan-request';

describe('buildPlanGoal', () => {
  it('describes style, days, time and equipment', () => {
    const goal = buildPlanGoal(
      planRequestSchema.parse({
        style: 'POWERLIFTING',
        daysPerWeek: 4,
        sessionMinutes: 75,
        equipment: 'FULL_GYM',
        focusAreas: ['Back'],
        notes: 'bad left knee',
      }),
    );
    expect(goal).toContain('4 day per week');
    expect(goal).toContain('powerlifting');
    expect(goal).toContain('75 minutes');
    expect(goal).toContain('commercial gym');
    expect(goal).toContain('Back');
    expect(goal).toContain('bad left knee');
  });

  it('omits optional lines when absent', () => {
    const goal = buildPlanGoal(
      planRequestSchema.parse({ style: 'GENERAL', daysPerWeek: 3, sessionMinutes: 45, equipment: 'BODYWEIGHT' }),
    );
    expect(goal).not.toContain('extra weekly volume');
    expect(goal).not.toContain('Extra notes');
  });
});

describe('buildQuickWorkoutGoal', () => {
  it('asks for exactly one workout of the right length', () => {
    const goal = buildQuickWorkoutGoal(
      quickWorkoutRequestSchema.parse({ equipment: 'HOTEL', minutes: 30, focus: 'UPPER', intensity: 'HARD' }),
    );
    expect(goal).toContain('exactly ONE workout');
    expect(goal).toContain('30 minutes');
    expect(goal).toContain('hotel gym');
    expect(goal).toContain('Make it hard');
  });
});

describe('request schemas', () => {
  it('rejects out of range values', () => {
    expect(planRequestSchema.safeParse({ style: 'GENERAL', daysPerWeek: 9, sessionMinutes: 45, equipment: 'FULL_GYM' }).success).toBe(false);
    expect(quickWorkoutRequestSchema.safeParse({ equipment: 'FULL_GYM', minutes: 5, focus: 'CORE' }).success).toBe(false);
  });
});

describe('expectedExerciseRange', () => {
  it('scales with time', () => {
    expect(expectedExerciseRange(60).max).toBeGreaterThan(expectedExerciseRange(20).max);
  });
});
