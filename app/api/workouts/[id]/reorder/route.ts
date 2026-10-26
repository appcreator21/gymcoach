import { NextResponse } from 'next/server';
import { z } from 'zod';
import { db } from '@/lib/db';
import { ApiError, handleApiError, parseJsonBody, requireApiUserId } from '@/lib/api';
import { validateReorder } from '@/lib/reorder';

const bodySchema = z.object({ ids: z.array(z.string().min(1)).min(1).max(100) });

// POST /api/workouts/[id]/reorder: sets the order of a workout's exercises.
// ids is the full list of program exercise ids in the new order.
export async function POST(req: Request, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  try {
    const userId = await requireApiUserId();
    const { ids } = await parseJsonBody(req, bodySchema);
    const workout = await db.workout.findFirst({
      where: { id: params.id, program: { userId } },
      select: { exercises: { select: { id: true } } },
    });
    if (!workout) throw new ApiError(404, 'Workout not found.');
    const problem = validateReorder(workout.exercises.map((e) => e.id), ids);
    if (problem) throw new ApiError(400, problem);

    await db.$transaction(
      ids.map((id, index) =>
        db.programExercise.update({ where: { id, workoutId: params.id }, data: { order: index + 1 } }),
      ),
    );
    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
