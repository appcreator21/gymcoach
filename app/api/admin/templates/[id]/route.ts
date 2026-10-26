import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { ApiError, handleApiError } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { parseTemplateData } from '@/lib/admin-programs';

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
