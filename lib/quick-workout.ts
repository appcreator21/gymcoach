import { db } from '@/lib/db';
import { addWorkoutToProgram, generateProgram } from '@/lib/program-generation';
import { buildQuickWorkoutGoal } from '@/lib/plan-brief';
import { LlmError } from '@/lib/llm';
import type { QuickWorkoutRequest } from '@/lib/schemas/plan-request';

export const QUICK_PROGRAM_NAME = 'Quick Workouts';

// Asks Surba for one workout and files it in the user's "Quick Workouts"
// program (created on first use, never active), so it can be started like any
// other workout without disturbing the active plan.
export async function createQuickWorkout(userId: string, req: QuickWorkoutRequest) {
  const draft = await generateProgram(userId, buildQuickWorkoutGoal(req));
  const workout = draft.workouts[0];
  if (!workout) throw new LlmError(502, 'Surba did not return a workout. Try again.');

  const existing = await db.program.findFirst({
    where: { userId, name: QUICK_PROGRAM_NAME },
    select: { id: true },
  });
  const programId =
    existing?.id ??
    (
      await db.program.create({
        data: {
          userId,
          name: QUICK_PROGRAM_NAME,
          phase: 'Quick',
          description: 'One-off workouts built by Surba.',
          isActive: false,
        },
        select: { id: true },
      })
    ).id;

  const workoutId = await addWorkoutToProgram(userId, programId, { ...workout, dayOfWeek: null });
  return { programId, workoutId };
}
