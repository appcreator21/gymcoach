import { NextResponse } from 'next/server';
import { z } from 'zod';
import { db } from '@/lib/db';
import { ApiError, handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { parseTemplateData, saveProgramForUser } from '@/lib/admin-programs';

const MAX_CLIENTS = 100;

// One client (`userId`) or several (`userIds`).
const bodySchema = z
  .object({
    userId: z.string().min(1).optional(),
    userIds: z.array(z.string().min(1)).min(1).max(MAX_CLIENTS).optional(),
    activate: z.boolean().optional().default(true),
  })
  .refine((b) => b.userId || b.userIds, { message: 'Pick at least one client.' });

// POST /api/admin/templates/[id]/assign: copies a template into one or more
// clients' accounts (new exercises are created by name, existing ones reused).
// Each client is independent: a failure for one does not undo the others.
export async function POST(req: Request, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const body = await parseJsonBody(req, bodySchema);
    const wanted = [...new Set([...(body.userIds ?? []), ...(body.userId ? [body.userId] : [])])];

    const template = await db.programTemplate.findUnique({ where: { id: params.id } });
    if (!template) throw new ApiError(404, 'Template not found.');
    const program = parseTemplateData(template.data);

    const found = await db.user.findMany({
      where: { id: { in: wanted } },
      select: { id: true },
    });
    const existing = new Set(found.map((u) => u.id));
    if (wanted.length === 1 && !existing.has(wanted[0]!)) {
      throw new ApiError(404, 'User not found.');
    }

    const assigned: { userId: string; programId: string }[] = [];
    const failed: { userId: string; error: string }[] = [];
    for (const userId of wanted) {
      if (!existing.has(userId)) {
        failed.push({ userId, error: 'User not found.' });
        continue;
      }
      try {
        assigned.push({
          userId,
          programId: await saveProgramForUser(userId, program, body.activate),
        });
      } catch (err) {
        console.error('[assign] failed for user', userId, err);
        failed.push({ userId, error: 'Could not assign to this client.' });
      }
    }

    if (assigned.length === 0) {
      throw new ApiError(500, failed[0]?.error ?? 'Could not assign the template.');
    }
    return NextResponse.json({ id: assigned[0]!.programId, assigned, failed }, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
