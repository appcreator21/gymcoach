import { NextResponse } from 'next/server';
import { z } from 'zod';
import { db } from '@/lib/db';
import { ApiError, handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { parseTemplateData, saveProgramForUser } from '@/lib/admin-programs';

const bodySchema = z.object({
  userId: z.string().min(1),
  activate: z.boolean().optional().default(true),
});

// POST /api/admin/templates/[id]/assign: copies a template into a client's
// account (new exercises are created by name, existing ones reused).
export async function POST(req: Request, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const { userId, activate } = await parseJsonBody(req, bodySchema);
    const [template, user] = await Promise.all([
      db.programTemplate.findUnique({ where: { id: params.id } }),
      db.user.findUnique({ where: { id: userId }, select: { id: true } }),
    ]);
    if (!template) throw new ApiError(404, 'Template not found.');
    if (!user) throw new ApiError(404, 'User not found.');
    const id = await saveProgramForUser(userId, parseTemplateData(template.data), activate);
    return NextResponse.json({ id }, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
