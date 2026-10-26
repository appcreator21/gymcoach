import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError } from '@/lib/api';
import { adminEmailList, requireAdminUserId } from '@/lib/admin';

// GET /api/admin/users?q=: clients with a few activity numbers each.
export async function GET(req: Request) {
  try {
    await requireAdminUserId();
    const q = new URL(req.url).searchParams.get('q')?.trim();
    const users = await db.user.findMany({
      where: q
        ? {
            OR: [
              { email: { contains: q, mode: 'insensitive' } },
              { displayName: { contains: q, mode: 'insensitive' } },
            ],
          }
        : undefined,
      orderBy: { createdAt: 'desc' },
      take: 200,
      select: {
        id: true,
        email: true,
        displayName: true,
        role: true,
        createdAt: true,
        goal: true,
        _count: { select: { sessions: true } },
        sessions: { orderBy: { startedAt: 'desc' }, take: 1, select: { startedAt: true } },
        programs: { where: { isActive: true }, take: 1, select: { name: true } },
      },
    });
    const envAdmins = adminEmailList();
    return NextResponse.json(
      users.map((u) => ({
        id: u.id,
        email: u.email,
        displayName: u.displayName,
        role: envAdmins.includes(u.email.toLowerCase()) ? 'ADMIN' : u.role,
        createdAt: u.createdAt,
        goal: u.goal,
        sessionCount: u._count.sessions,
        lastSessionAt: u.sessions[0]?.startedAt ?? null,
        activeProgram: u.programs[0]?.name ?? null,
      })),
    );
  } catch (err) {
    return handleApiError(err);
  }
}
