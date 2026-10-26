import { NextResponse } from 'next/server';
import { z } from 'zod';
import { db } from '@/lib/db';
import { ApiError, handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { buildProgramFromGenerated } from '@/lib/program-generation';
import { generatedProgramSchema } from '@/lib/schemas/program-generation';

const bodySchema = z.object({
  userId: z.string().min(1),
  program: generatedProgramSchema,
  // Make it the client's active program right away.
  activate: z.boolean().optional().default(false),
});

// POST /api/admin/programs/build: saves a reviewed draft into a client's
// account, optionally activating it.
export async function POST(req: Request) {
  try {
    await requireAdminUserId();
    const { userId, program, activate } = await parseJsonBody(req, bodySchema);
    const target = await db.user.findUnique({ where: { id: userId }, select: { id: true } });
    if (!target) throw new ApiError(404, 'User not found.');

    const id = await buildProgramFromGenerated(userId, program);
    if (activate) {
      await db.$transaction([
        db.program.updateMany({
          where: { userId, isActive: true, id: { not: id } },
          data: { isActive: false },
        }),
        db.program.update({ where: { id }, data: { isActive: true } }),
      ]);
    }
    return NextResponse.json({ id }, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
