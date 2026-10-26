import { NextResponse } from 'next/server';
import { z } from 'zod';
import type { Prisma } from '@/lib/prisma-client';
import { db } from '@/lib/db';
import { handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { generatedProgramSchema } from '@/lib/schemas/program-generation';

// GET /api/admin/templates: saved programs, newest first, with a summary.
export async function GET() {
  try {
    await requireAdminUserId();
    const rows = await db.programTemplate.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return NextResponse.json(
      rows.map((t) => {
        const parsed = generatedProgramSchema.safeParse(t.data);
        return {
          id: t.id,
          name: t.name,
          description: t.description,
          phase: t.phase,
          createdAt: t.createdAt,
          workoutCount: parsed.success ? parsed.data.workouts.length : 0,
          exerciseCount: parsed.success
            ? parsed.data.workouts.reduce((n, w) => n + w.exercises.length, 0)
            : 0,
          valid: parsed.success,
        };
      }),
    );
  } catch (err) {
    return handleApiError(err);
  }
}

const bodySchema = z.object({ program: generatedProgramSchema });

// POST /api/admin/templates: saves a reviewed draft as a reusable template.
export async function POST(req: Request) {
  try {
    const adminId = await requireAdminUserId();
    const { program } = await parseJsonBody(req, bodySchema);
    const created = await db.programTemplate.create({
      data: {
        name: program.name,
        description: program.description ?? null,
        phase: program.phase,
        data: program as unknown as Prisma.InputJsonValue,
        createdById: adminId,
      },
      select: { id: true },
    });
    return NextResponse.json(created, { status: 201 });
  } catch (err) {
    return handleApiError(err);
  }
}
