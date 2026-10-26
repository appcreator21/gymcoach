import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';

// GET /api/admin/overview: headline numbers for the admin dashboard.
export async function GET() {
  try {
    await requireAdminUserId();
    const day = 24 * 60 * 60 * 1000;
    const week = new Date(Date.now() - 7 * day);
    const month = new Date(Date.now() - 30 * day);

    const [users, newUsers, sessionsTotal, sessionsWeek, setsWeek, activeUsersWeek, recent] =
      await Promise.all([
        db.user.count(),
        db.user.count({ where: { createdAt: { gte: month } } }),
        db.session.count({ where: { finishedAt: { not: null } } }),
        db.session.count({ where: { finishedAt: { not: null }, startedAt: { gte: week } } }),
        db.set.count({ where: { completedAt: { gte: week }, isWarmup: false } }),
        db.session.findMany({
          where: { startedAt: { gte: week } },
          distinct: ['userId'],
          select: { userId: true },
        }),
        db.user.findMany({
          orderBy: { createdAt: 'desc' },
          take: 5,
          select: { id: true, email: true, displayName: true, createdAt: true },
        }),
      ]);

    return NextResponse.json({
      users,
      newUsers30d: newUsers,
      sessionsTotal,
      sessions7d: sessionsWeek,
      sets7d: setsWeek,
      activeUsers7d: activeUsersWeek.length,
      recentSignups: recent,
    });
  } catch (err) {
    return handleApiError(err);
  }
}
