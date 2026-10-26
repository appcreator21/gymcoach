import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { ApiError, handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { exerciseInputSchema } from '@/lib/schemas/exercise';

interface Params {
  params: Promise<{ id: string; exerciseId: string }>;
}

// Every query is scoped to the client in the URL, so an exercise id from
// another account is a 404 here as well.

export async function PUT(req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const data = await parseJsonBody(req, exerciseInputSchema);
    const updated = await db.exercise.update({
      where: { id: params.exerciseId, userId: params.id },
      data: { ...data, notes: data.notes ?? null },
    });
    return NextResponse.json(updated);
  } catch (err) {
    return handleApiError(err);
  }
}

// An exercise that is used by a program or has history cannot be deleted.
export async function DELETE(_req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const usage = await db.exercise.findFirst({
      where: { id: params.exerciseId, userId: params.id },
      select: { _count: { select: { programExercises: true, sets: true } } },
    });
    if (!usage) throw new ApiError(404, 'Exercise not found.');
    if (usage._count.programExercises > 0 || usage._count.sets > 0) {
      throw new ApiError(409, 'Exercise used in a program or in history. Remove it first.');
    }
    await db.exercise.delete({ where: { id: params.exerciseId, userId: params.id } });
    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
