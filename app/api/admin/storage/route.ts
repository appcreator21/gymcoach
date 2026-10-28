import { NextResponse } from 'next/server';
import { handleApiError } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { getStorageConfig, MAX_UPLOAD_MB } from '@/lib/storage';

// GET /api/admin/storage: whether video uploads are set up. The app uses it to
// show the upload button, or to explain that links still work.
export async function GET() {
  try {
    await requireAdminUserId();
    return NextResponse.json({ configured: getStorageConfig() !== null, provider: 'r2', maxMb: MAX_UPLOAD_MB });
  } catch (err) {
    return handleApiError(err);
  }
}
