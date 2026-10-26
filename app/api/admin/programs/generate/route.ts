import { NextResponse } from 'next/server';
import { z } from 'zod';
import { db } from '@/lib/db';
import { ApiError, handleApiError, parseJsonBody } from '@/lib/api';
import { requireAdminUserId } from '@/lib/admin';
import { LlmError } from '@/lib/llm';
import { rateLimit } from '@/lib/rate-limit';
import { generateProgram } from '@/lib/program-generation';

const bodySchema = z.object({
  goal: z.string().trim().min(10, 'Describe the program in a bit more detail.').max(2000),
  // The client the program is designed for; defaults to the admin themself.
  userId: z.string().min(1).optional(),
});

// POST /api/admin/programs/generate: Surba drafts a program for a client,
// using that client's profile and exercise catalog as context. Nothing is
// persisted; the draft is previewed and saved through /build.
export async function POST(req: Request) {
  try {
    const adminId = await requireAdminUserId();
    const rl = rateLimit(`admin-generate:${adminId}`, 10, 60_000);
    if (!rl.ok) {
      return NextResponse.json(
        { error: 'Too many generations. Please wait a moment.' },
        { status: 429, headers: { 'Retry-After': String(rl.retryAfterSec) } },
      );
    }
    const { goal, userId } = await parseJsonBody(req, bodySchema);
    const targetId = userId ?? adminId;
    const target = await db.user.findUnique({ where: { id: targetId }, select: { id: true } });
    if (!target) throw new ApiError(404, 'User not found.');
    const program = await generateProgram(targetId, goal);
    return NextResponse.json({ program });
  } catch (err) {
    if (err instanceof LlmError) {
      return NextResponse.json({ error: err.message }, { status: err.status });
    }
    return handleApiError(err);
  }
}
