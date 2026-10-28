import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { videoInputSchema } from '@/lib/schemas/video';

export async function GET() {
  try {
    await requireAdminUserId();
    const clips = await db.videoClip.findMany({ orderBy: { createdAt: 'desc' }, take: 300 });
    return NextResponse.json(clips);
  } catch (err) {
    return handleApiError(err);
  }
}

export async function POST(req: Request) {
  try {
    const adminId = await requireAdminUserId();
    const data = await parseJsonBody(req, videoInputSchema);
    const created = await db.videoClip.create({
      data: {
        title: data.title,
        description: data.description ?? null,
        videoUrl: data.videoUrl,
        thumbnailUrl: data.thumbnailUrl ?? null,
        category: data.category,
        exerciseName: data.exerciseName ?? null,
        workoutName: data.workoutName ?? null,
        storageKey: data.storageKey ?? null,
        thumbnailKey: data.thumbnailKey ?? null,
        durationSec: data.durationSec ?? null,
        featured: data.featured,
        createdById: adminId,
      },
    });
    return NextResponse.json(created, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
