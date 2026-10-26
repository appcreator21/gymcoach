import { describe, it, expect } from 'vitest';
import { parseTemplateData } from './admin-programs';

const valid = {
  name: 'Upper Lower',
  phase: 'Hypertrophy',
  workouts: [
    {
      name: 'Upper',
      exercises: [
        {
          name: 'Bench Press',
          muscleGroup: 'CHEST',
          category: 'COMPOUND',
          targetSets: 3,
          targetRepsMin: 6,
          targetRepsMax: 8,
          targetRIR: 2,
          restSec: 150,
        },
      ],
    },
  ],
};

describe('parseTemplateData', () => {
  it('accepts a valid stored program', () => {
    expect(parseTemplateData(valid).name).toBe('Upper Lower');
  });

  it('rejects malformed data with a 422', () => {
    expect(() => parseTemplateData({ name: 'x' })).toThrowError(/no longer valid/);
  });
});
