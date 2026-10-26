import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { ApiError, handleApiError, requireApiUserId } from '@/lib/api';

interface Params {
  params: Promise<{ id: string }>;
}

// POST joins, DELETE leaves. Joining shows your first name and last initial
// on that challenge's leaderboard; nothing else about you is shared.
export async function POST(_req: Request, props: Params) {
  const params = await props.params;
  try {
    const userId = await requireApiUserId();
    const challenge = await db.challenge.findUnique({ where: { id: params.id } });
    if (!challenge) throw new ApiError(404, 'Challenge not found.');
    if (challenge.endsAt < new Date()) throw new ApiError(400, 'This challenge has ended.');
    await db.challengeEntry.upsert({
      where: { challengeId_userId: { challengeId: params.id, userId } },
      update: {},
      create: { challengeId: params.id, userId },
    });
    return NextResponse.json({ ok: true }, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}

export async function DELETE(_req: Request, props: Params) {
  const params = await props.params;
  try {
    const userId = await requireApiUserId();
    await db.challengeEntry.deleteMany({ where: { challengeId: params.id, userId } });
    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
