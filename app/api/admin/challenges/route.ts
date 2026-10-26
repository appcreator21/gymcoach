import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { challengeInputSchema } from '@/lib/schemas/challenge';

export async function GET() {
  try {
    await requireAdminUserId();
    const rows = await db.challenge.findMany({
      orderBy: { startsAt: 'desc' },
      take: 100,
      include: { _count: { select: { entries: true } } },
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
      })),
    );
  } catch (err) {
    return handleApiError(err);
  }
}

export async function POST(req: Request) {
  try {
    const adminId = await requireAdminUserId();
    const data = await parseJsonBody(req, challengeInputSchema);
    const created = await db.challenge.create({
      data: { ...data, description: data.description ?? null, createdById: adminId },
      select: { id: true },
    });
    return NextResponse.json(created, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
