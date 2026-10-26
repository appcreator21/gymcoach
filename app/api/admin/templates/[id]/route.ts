import { NextResponse } from 'next/server';
import { z } from 'zod';
import type { Prisma } from '@/lib/prisma-client';
import { db } from '@/lib/db';
import { ApiError, handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { parseTemplateData } from '@/lib/admin-programs';
import { generatedProgramSchema } from '@/lib/schemas/program-generation';

interface Params {
  params: Promise<{ id: string }>;
}

// GET /api/admin/templates/[id]: the full program, for a preview.
export async function GET(_req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const t = await db.programTemplate.findUnique({ where: { id: params.id } });
    if (!t) throw new ApiError(404, 'Template not found.');
    return NextResponse.json({ id: t.id, program: parseTemplateData(t.data) });
  } catch (err) {
    return handleApiError(err);
  }
}

const patchSchema = z.object({ program: generatedProgramSchema });

// PATCH /api/admin/templates/[id]: replaces the template with an edited program.
export async function PATCH(req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    const { program } = await parseJsonBody(req, patchSchema);
    const existing = await db.programTemplate.findUnique({
      where: { id: params.id },
      select: { id: true },
    });
    if (!existing) throw new ApiError(404, 'Template not found.');
    await db.programTemplate.update({
      where: { id: params.id },
      data: {
        name: program.name,
        description: program.description ?? null,
        phase: program.phase,
        data: program as unknown as Prisma.InputJsonValue,
      },
    });
    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}

// DELETE /api/admin/templates/[id]
export async function DELETE(_req: Request, props: Params) {
  const params = await props.params;
  try {
    await requireAdminUserId();
    await db.programTemplate.delete({ where: { id: params.id } });
    return NextResponse.json({ ok: true });
  } catch (err) {
    return handleApiError(err);
  }
}
