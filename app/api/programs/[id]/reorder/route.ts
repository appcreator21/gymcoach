import { NextResponse } from 'next/server';
import { z } from 'zod';
import { db } from '@/lib/db';
import { ApiError, handleApiError, parseJsonBody, requireApiUserId } from '@/lib/api';
import { validateReorder } from '@/lib/reorder';

const bodySchema = z.object({ ids: z.array(z.string().min(1)).min(1).max(50) });

// POST /api/programs/[id]/reorder: sets the order of a program's workouts.
export async function POST(req: Request, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  try {
    const userId = await requireApiUserId();
    const { ids } = await parseJsonBody(req, bodySchema);
    const program = await db.program.findFirst({
      where: { id: params.id, userId },
      select: { workouts: { select: { id: true } } },
    });
    if (!program) throw new ApiError(404, 'Program not found.');
    const problem = validateReorder(program.workouts.map((w) => w.id), ids);
    if (problem) throw new ApiError(400, problem);

    await db.$transaction(
      ids.map((id, index) =>
        db.workout.update({ where: { id, programId: params.id }, data: { order: index + 1 } }),
      ),
    );
    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
