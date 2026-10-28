import { NextResponse } from 'next/server';
import { z } from 'zod';
import { handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { rateLimit } from '@/lib/rate-limit';
import {
  buildKey,
  getStorageConfig,
  IMAGE_TYPES,
  MAX_UPLOAD_MB,
  presignUpload,
  publicUrl,
  VIDEO_TYPES,
} from '@/lib/storage';

const bodySchema = z.object({
  fileName: z.string().trim().min(1).max(200),
  contentType: z.enum(VIDEO_TYPES),
  sizeBytes: z.number().int().positive().max(MAX_UPLOAD_MB * 1024 * 1024).optional(),
  // Also sign a thumbnail upload (a JPEG or PNG made on the phone).
  thumbnail: z
    .object({ fileName: z.string().trim().min(1).max(200), contentType: z.enum(IMAGE_TYPES) })
    .optional(),
});

// POST /api/admin/videos/upload-url: signed links to upload a video (and its
// thumbnail) straight to storage. Keys are generated here. With no storage
// configured it answers 503, and the app falls back to pasting links.
export async function POST(req: Request) {
  try {
    const adminId = await requireAdminUserId();
    const config = getStorageConfig();
    if (!config) {
      return NextResponse.json(
        { error: 'Video storage is not connected yet. Paste a link instead.', configured: false },
        { status: 503 },
      );
    }
    const rl = rateLimit(`video-upload:${adminId}`, 20, 60_000);
    if (!rl.ok) {
      return NextResponse.json(
        { error: 'Too many uploads. Please wait a moment.' },
        { status: 429, headers: { 'Retry-After': String(rl.retryAfterSec) } },
      );
    }
    const body = await parseJsonBody(req, bodySchema);
    const id = crypto.randomUUID();

    const videoKey = buildKey('video', body.fileName, id);
    interface SignedUpload {
      key: string;
      contentType: string;
      uploadUrl: string;
      publicUrl: string;
    }
    const video: SignedUpload = {
      key: videoKey,
      contentType: body.contentType,
      uploadUrl: await presignUpload(config, videoKey, body.contentType),
      publicUrl: publicUrl(config, videoKey),
    };

    let thumbnail: SignedUpload | undefined;
    if (body.thumbnail) {
      const thumbKey = buildKey('thumb', body.thumbnail.fileName, id);
      thumbnail = {
        key: thumbKey,
        contentType: body.thumbnail.contentType,
        uploadUrl: await presignUpload(config, thumbKey, body.thumbnail.contentType),
        publicUrl: publicUrl(config, thumbKey),
      };
    }
    return NextResponse.json({ configured: true, video, thumbnail });
  } catch (err) {
    return handleApiError(err);
  }
}
