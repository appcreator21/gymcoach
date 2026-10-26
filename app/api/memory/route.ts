import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError, requireApiUserId } from '@/lib/api';

// GET /api/memory: the memory file the AI coach keeps about the caller.
export async function GET() {
  try {
    const userId = await requireApiUserId();
    const user = await db.user.findUnique({
      where: { id: userId },
      select: { memory: true, memoryUpdatedAt: true },
    });
    return NextResponse.json({
      memory: user?.memory ?? '',
      updatedAt: user?.memoryUpdatedAt ?? null,
    });
  } catch (err) {
    return handleApiError(err);
  }
}
