import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError, requireApiUserId } from '@/lib/api';

// GET /api/videos: the coach's videos, featured first, newest first.
export async function GET() {
  try {
    await requireApiUserId();
    const clips = await db.videoClip.findMany({
      orderBy: [{ featured: 'desc' }, { createdAt: 'desc' }],
      take: 200,
      select: {
        id: true,
        title: true,
        description: true,
        videoUrl: true,
        thumbnailUrl: true,
        category: true,
        exerciseName: true,
        workoutName: true,
        durationSec: true,
        featured: true,
        createdAt: true,
      },
    });
    return NextResponse.json(clips);
  } catch (err) {
    return handleApiError(err);
  }
}
