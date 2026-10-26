import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError, requireApiUserId } from '@/lib/api';

// GET /api/announcements: what the admin posted, pinned first, newest first.
export async function GET() {
  try {
    await requireApiUserId();
    const items = await db.announcement.findMany({
      orderBy: [{ pinned: 'desc' }, { createdAt: 'desc' }],
      take: 10,
      select: { id: true, title: true, body: true, pinned: true, createdAt: true },
    });
    return NextResponse.json(items);
  } catch (err) {
    return handleApiError(err);
  }
}
