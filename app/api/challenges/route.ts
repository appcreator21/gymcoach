import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError, requireApiUserId } from '@/lib/api';
import { challengeStatus } from '@/lib/challenges';

// GET /api/challenges: current and recent challenges with my join state.
export async function GET() {
  try {
    const userId = await requireApiUserId();
    const since = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const rows = await db.challenge.findMany({
      where: { endsAt: { gte: since } },
      orderBy: { startsAt: 'desc' },
      take: 50,
      include: {
        _count: { select: { entries: true } },
        entries: { where: { userId }, select: { userId: true } },
      },
    });
    return NextResponse.json(
      rows.map((c) => ({
        id: c.id,
        title: c.title,
        description: c.description,
        metric: c.metric,
        startsAt: c.startsAt,
        endsAt: c.endsAt,
        participants: c._count.entries,
        joined: c.entries.length > 0,
        status: challengeStatus(c.startsAt, c.endsAt),
      })),
    );
  } catch (err) {
    return handleApiError(err);
  }
}
