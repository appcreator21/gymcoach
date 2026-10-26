import { db } from '@/lib/db';
import { getLlmProvider, LlmError } from '@/lib/llm';
import { PROGRAM_GEN_SYSTEM_PROMPT } from '@/lib/prompts/program-system-prompt';
import {
  parseGeneratedProgram,
  type GeneratedExercise,
  type GeneratedProgram,
  type GeneratedWorkout,
} from '@/lib/schemas/program-generation';
import { defaultIntraSetConfig } from '@/lib/intra-set-autoregulation';
import type { Prisma } from '@/lib/prisma-client';

// Headroom over Prisma's 5 s default for the pooled connection's round trips.
const TRANSACTION_OPTIONS = { timeout: 20_000, maxWait: 10_000 };

// Generates a structured program draft from a natural-language goal. Does not
// persist anything: the result is previewed (and edited) before saving.
export async function generateProgram(userId: string, goal: string): Promise<GeneratedProgram> {
  const provider = getLlmProvider();

  const [user, exercises] = await Promise.all([
    db.user.findUnique({
      where: { id: userId },
      select: {
        sex: true,
        heightCm: true,
        bodyweight: true,
        goal: true,
        weeklyFrequency: true,
      },
    }),
    db.exercise.findMany({
      where: { userId },
      select: { name: true, muscleGroup: true, category: true, equipmentType: true },
      orderBy: { name: 'asc' },
    }),
  ]);

  const context = {
    profile: {
      sex: user?.sex ?? null,
      heightCm: user?.heightCm ?? null,
      bodyweight: user?.bodyweight ?? null,
      goal: user?.goal ?? null,
      weeklyFrequency: user?.weeklyFrequency ?? null,
    },
    availableExercises: exercises,
  };

  const userMessage = `User goal:\n${goal}\n\nContext (JSON):\n${JSON.stringify(context, null, 2)}`;

  const { text } = await provider.complete({
    system: PROGRAM_GEN_SYSTEM_PROMPT,
    messages: [{ role: 'user', content: userMessage }],
    maxTokens: 8000,
  });

  const parsed = parseGeneratedProgram(text);
  if (!parsed.ok) {
    throw new LlmError(502, `The generated program could not be parsed: ${parsed.error}`);
  }
  return parsed.program;
}

// Persists a (possibly user-edited) generated program in a single transaction.
// New exercises are created on the fly; existing ones are reused by name.
// Returns the new program id. The program is created inactive.
export async function buildProgramFromGenerated(
  userId: string,
  program: GeneratedProgram,
): Promise<string> {
  return db.$transaction(async (tx) => {
    const created = await tx.program.create({
      data: {
        userId,
        name: program.name,
        description: program.description ?? null,
        phase: program.phase,
        isActive: false,
      },
    });

    await createGeneratedWorkouts(tx, userId, created.id, program.workouts, 1);
    return created.id;
  }, TRANSACTION_OPTIONS);
}

// Appends one generated workout to an EXISTING program the user owns, after
// its current last workout. Same exercise reuse and cardio rules as a full
// build. Returns the new workout id. Throws when the program is not the
// user's (or does not exist) so a caller cannot write into someone else's
// program by guessing an id.
export async function addWorkoutToProgram(
  userId: string,
  programId: string,
  workout: GeneratedWorkout,
): Promise<string> {
  return db.$transaction(async (tx) => {
    const program = await tx.program.findFirst({
      where: { id: programId, userId },
      select: { id: true },
    });
    if (!program) throw new Error('Program not found.');

    const last = await tx.workout.findFirst({
      where: { programId },
      orderBy: { order: 'desc' },
      select: { order: true },
    });
    const ids = await createGeneratedWorkouts(
      tx,
      userId,
      programId,
      [workout],
      (last?.order ?? 0) + 1,
    );
    return ids[0]!;
  }, TRANSACTION_OPTIONS);
}

// Persists workouts and their exercises inside an open transaction using a
// handful of bulk queries (not one per exercise): the app talks to Postgres
// through a pooler, so every round trip costs real latency and a per-exercise
// loop used to exceed the interactive transaction timeout. New exercises are
// created on the fly; existing ones are reused by name. Returns the new
// workout ids in order.
async function createGeneratedWorkouts(
  tx: Prisma.TransactionClient,
  userId: string,
  programId: string,
  workouts: GeneratedWorkout[],
  firstOrder: number,
): Promise<string[]> {
  const firstSeen = new Map<string, GeneratedExercise>();
  for (const w of workouts) {
    for (const ex of w.exercises) if (!firstSeen.has(ex.name)) firstSeen.set(ex.name, ex);
  }
  const names = [...firstSeen.keys()];

  const known = new Map(
    (await tx.exercise.findMany({ where: { userId, name: { in: names } } })).map((e) => [
      e.name,
      e,
    ]),
  );
  const missing = names.filter((name) => !known.has(name));
  if (missing.length > 0) {
    await tx.exercise.createMany({
      data: missing.map((name) => {
        const ex = firstSeen.get(name)!;
        return {
          userId,
          name,
          muscleGroup: ex.muscleGroup,
          // A CARDIO machine is always logged as cardio (duration/distance),
          // whatever category the model picked.
          category: ex.equipmentType === 'CARDIO' ? ('CARDIO' as const) : ex.category,
          equipmentType: ex.equipmentType ?? 'OTHER',
          defaultRestSec: ex.restSec,
        };
      }),
      skipDuplicates: true,
    });
    for (const e of await tx.exercise.findMany({ where: { userId, name: { in: missing } } })) {
      known.set(e.name, e);
    }
  }

  const workoutRows = workouts.map((w, index) => ({
    id: crypto.randomUUID(),
    programId,
    name: w.name,
    dayOfWeek: w.dayOfWeek ?? null,
    order: firstOrder + index,
  }));
  await tx.workout.createMany({ data: workoutRows });

  const programExercises = workouts.flatMap((w, workoutIndex) =>
    w.exercises.map((ex, exerciseIndex) => {
      const exercise = known.get(ex.name)!;
      const autoregDefaults = defaultIntraSetConfig(exercise);
      return {
        workoutId: workoutRows[workoutIndex]!.id,
        exerciseId: exercise.id,
        order: exerciseIndex + 1,
        targetSets: ex.targetSets,
        targetRepsMin: ex.targetRepsMin,
        targetRepsMax: Math.max(ex.targetRepsMax, ex.targetRepsMin),
        targetRIR: ex.targetRIR,
        restSec: ex.restSec,
        autoregulationMode: ex.autoregulationMode ?? ('PRESERVE_RIR' as const),
        fatigueRate: ex.fatigueRate ?? autoregDefaults.fatigueRate,
        loadAdjustmentPct: ex.loadAdjustmentPct ?? autoregDefaults.loadAdjustmentPct,
        tempo: ex.tempo ?? null,
        notes: ex.notes ?? null,
        supersetGroup: ex.supersetGroup ?? null,
      };
    }),
  );
  await tx.programExercise.createMany({ data: programExercises });

  return workoutRows.map((row) => row.id);
}
