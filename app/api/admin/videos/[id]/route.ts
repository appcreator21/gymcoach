import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { videoInputSchema } from '@/lib/schemas/video';
import { deleteObject, getStorageConfig } from '@/lib/storage';

interface Params {
  params: Promise<{ id: string }>;
}

export async function PUT(req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const data = await parseJsonBody(req, videoInputSchema);
    const before = await db.videoClip.findUnique({
      where: { id: params.id },
      select: { storageKey: true, thumbnailKey: true },
    });
    const updated = await db.videoClip.update({
      where: { id: params.id },
      data: {
        title: data.title,
        description: data.description ?? null,
        videoUrl: data.videoUrl,
        thumbnailUrl: data.thumbnailUrl ?? null,
        category: data.category,
        exerciseName: data.exerciseName ?? null,
        workoutName: data.workoutName ?? null,
        durationSec: data.durationSec ?? null,
        featured: data.featured,
        // Undefined leaves the stored key alone; a new upload replaces it.
        storageKey: data.storageKey,
        thumbnailKey: data.thumbnailKey,
      },
    });
    // A replaced file is no longer referenced: remove it, best effort.
    const config = getStorageConfig();
    if (config && before) {
      for (const [oldKey, newKey] of [
        [before.storageKey, data.storageKey],
        [before.thumbnailKey, data.thumbnailKey],
      ] as const) {
        if (oldKey && newKey !== undefined && newKey !== oldKey) await deleteObject(config, oldKey);
      }
    }
    return NextResponse.json(updated);
  } catch (err) {
    return handleApiError(err);
  }
}

export async function DELETE(_req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const removed = await db.videoClip.delete({ where: { id: params.id } });
    // The files go with the video when they were uploaded to storage.
    const config = getStorageConfig();
    if (config) {
      for (const key of [removed.storageKey, removed.thumbnailKey]) if (key) await deleteObject(config, key);
    }
    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
