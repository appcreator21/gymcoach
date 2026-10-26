import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { ApiError, handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { exerciseInputSchema } from '@/lib/schemas/exercise';

interface Params {
  params: Promise<{ id: string }>;
}

// GET /api/admin/users/[id]/exercises: a client's exercise catalog, with how
// often each exercise is used.
export async function GET(_req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const exercises = await db.exercise.findMany({
      where: { userId: params.id },
      orderBy: [{ muscleGroup: 'asc' }, { name: 'asc' }],
      include: { _count: { select: { programExercises: true, sets: true } } },
    });
    return NextResponse.json(exercises);
  } catch (err) {
    return handleApiError(err);
  }
}

// POST /api/admin/users/[id]/exercises: adds an exercise to a client's catalog.
export async function POST(req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const user = await db.user.findUnique({ where: { id: params.id }, select: { id: true } });
    if (!user) throw new ApiError(404, 'User not found.');
    const data = await parseJsonBody(req, exerciseInputSchema);
    const created = await db.exercise.create({
      data: { ...data, userId: params.id, notes: data.notes ?? null },
    });
    return NextResponse.json(created, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
