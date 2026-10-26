import { NextResponse } from 'next/server';
import { z } from 'zod';
import { db } from '@/lib/db';
import { ApiError, handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';

interface Params {
  params: Promise<{ id: string }>;
}

// GET /api/admin/users/[id]: one client with programs, recent sessions and
// bodyweight.
export async function GET(_req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const user = await db.user.findUnique({
      where: { id: params.id },
      select: {
        id: true,
        email: true,
        displayName: true,
        role: true,
        createdAt: true,
        goal: true,
        weeklyFrequency: true,
        bodyweight: true,
        coachNote: true,
        programs: {
          orderBy: [{ isActive: 'desc' }, { createdAt: 'desc' }],
          take: 20,
          select: { id: true, name: true, phase: true, isActive: true, createdAt: true },
        },
        sessions: {
          orderBy: { startedAt: 'desc' },
          take: 15,
          select: {
            id: true,
            startedAt: true,
            finishedAt: true,
            workout: { select: { name: true } },
            _count: { select: { sets: true } },
          },
        },
      },
    });
    if (!user) throw new ApiError(404, 'User not found.');
    return NextResponse.json(user);
  } catch (err) {
    return handleApiError(err);
  }
}

const patchSchema = z.object({ role: z.enum(['USER', 'ADMIN']) });

// PATCH /api/admin/users/[id]: change a client's role. An admin cannot change
// their own role, so the last admin can never lock themselves out.
export async function PATCH(req: Request, props: Params) {
  const params = await props.params;
  try {
    const adminId = await requireAdminUserId();
    const { role } = await parseJsonBody(req, patchSchema);
    if (params.id === adminId) {
      throw new ApiError(400, 'You cannot change your own role.');
    }
    const updated = await db.user.update({
      where: { id: params.id },
      data: { role },
      select: { id: true, role: true },
    });
    return NextResponse.json(updated);
  } catch (err) {
    return handleApiError(err);
  }
}
