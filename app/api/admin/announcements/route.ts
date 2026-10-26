import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { announcementInputSchema } from '@/lib/schemas/announcement';

export async function GET() {
  try {
    await requireAdminUserId();
    const items = await db.announcement.findMany({
      orderBy: [{ pinned: 'desc' }, { createdAt: 'desc' }],
      take: 100,
    });
    return NextResponse.json(items);
  } catch (err) {
    return handleApiError(err);
  }
}

export async function POST(req: Request) {
  try {
    const adminId = await requireAdminUserId();
    const data = await parseJsonBody(req, announcementInputSchema);
    const created = await db.announcement.create({ data: { ...data, authorId: adminId } });
    return NextResponse.json(created, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
