import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { videoInputSchema } from '@/lib/schemas/video';

interface Params {
  params: Promise<{ id: string }>;
}

export async function PUT(req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const data = await parseJsonBody(req, videoInputSchema);
    const updated = await db.videoClip.update({
      where: { id: params.id },
      data: {
        title: data.title,
        description: data.description ?? null,
        videoUrl: data.videoUrl,
        thumbnailUrl: data.thumbnailUrl ?? null,
        category: data.category,
        exerciseName: data.exerciseName ?? null,
        durationSec: data.durationSec ?? null,
        featured: data.featured,
      },
    });
    return NextResponse.json(updated);
  } catch (err) {
    return handleApiError(err);
  }
}

export async function DELETE(_req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    await db.videoClip.delete({ where: { id: params.id } });
    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
