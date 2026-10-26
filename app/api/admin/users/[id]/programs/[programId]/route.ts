import { NextResponse } from 'next/server';
import { z } from 'zod';
import { db } from '@/lib/db';
import { ApiError, handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';

interface Params {
  params: Promise<{ id: string; programId: string }>;
}

// The program must belong to the client in the URL, so an admin cannot touch
// another client's program by pairing mismatched ids.
async function findClientProgram(userId: string, programId: string) {
  const program = await db.program.findFirst({
    where: { id: programId, userId },
    select: {
      id: true,
      name: true,
      phase: true,
      isActive: true,
      workouts: {
        orderBy: { order: 'asc' },
        select: {
          id: true,
          name: true,
          dayOfWeek: true,
          order: true,
          _count: { select: { exercises: true } },
        },
      },
    },
  });
  if (!program) throw new ApiError(404, 'Program not found.');
  return program;
}

// GET /api/admin/users/[id]/programs/[programId]: the program with its
// workouts and the weekday each one is scheduled on (1 = Monday ... 7 = Sunday).
export async function GET(_req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    return NextResponse.json(await findClientProgram(params.id, params.programId));
  } catch (err) {
    return handleApiError(err);
  }
}

const patchSchema = z.object({
  days: z
    .array(
      z.object({
        workoutId: z.string().min(1),
        // null = not tied to a weekday (the workout just comes up in rotation).
        dayOfWeek: z.number().int().min(1).max(7).nullable(),
      }),
    )
    .min(1)
    .max(14),
});

// PATCH /api/admin/users/[id]/programs/[programId]: sets which weekday each
// workout is scheduled on.
export async function PATCH(req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const { days } = await parseJsonBody(req, patchSchema);
    const program = await findClientProgram(params.id, params.programId);
    const own = new Set(program.workouts.map((w) => w.id));
    if (days.some((d) => !own.has(d.workoutId))) {
      throw new ApiError(400, 'A workout does not belong to this program.');
    }
    await db.$transaction(
      days.map((d) =>
        db.workout.update({ where: { id: d.workoutId }, data: { dayOfWeek: d.dayOfWeek } }),
      ),
    );
    return NextResponse.json(await findClientProgram(params.id, params.programId));
  } catch (err) {
    return handleApiError(err);
  }
}

// DELETE /api/admin/users/[id]/programs/[programId]: unassigns the program
// from the client. Their logged sessions stay (they just lose the program
// link), so history and records are never lost.
export async function DELETE(_req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    await findClientProgram(params.id, params.programId);
    await db.program.delete({ where: { id: params.programId } });
    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
