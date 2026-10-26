import { describe, expect, it } from 'vitest';
import { generatedProgramSchema } from '@/lib/schemas/program-generation';
import { PROGRAM_TEMPLATES } from '@/prisma/templates';

describe('starter program templates', () => {
  it('has unique names', () => {
    const names = PROGRAM_TEMPLATES.map((t) => t.name);
    expect(new Set(names).size).toBe(names.length);
  });

  it.each(PROGRAM_TEMPLATES.map((t) => [t.name, t] as const))(
    '%s is a valid program',
    (_name, template) => {
      expect(generatedProgramSchema.safeParse(template).success).toBe(true);
    },
  );

  it('never repeats an exercise inside one workout', () => {
    for (const t of PROGRAM_TEMPLATES) {
      for (const w of t.workouts) {
        const names = w.exercises.map((e) => e.name);
        expect(new Set(names).size, `${t.name} / ${w.name}`).toBe(names.length);
      }
    }
  });
});
