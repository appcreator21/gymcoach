import { NextResponse } from 'next/server';
import { handleApiError, parseJsonBody, requireApiUserId } from '@/lib/api';
import { LlmError } from '@/lib/llm';
import { rateLimit } from '@/lib/rate-limit';
import { generateProgram } from '@/lib/program-generation';
import { buildPlanGoal } from '@/lib/plan-brief';
import { planRequestSchema } from '@/lib/schemas/plan-request';

// POST /api/plans/generate: Surba drafts a plan from structured choices (style,
// days, session length, equipment, focus). Nothing is saved; the app previews
// the draft and saves it through /api/programs/from-template.
export async function POST(req: Request) {
  try {
    const userId = await requireApiUserId();
    const rl = rateLimit(`plan:${userId}`, 6, 60_000);
    if (!rl.ok) {
      return NextResponse.json(
        { error: 'Too many requests. Please wait a moment.' },
        { status: 429, headers: { 'Retry-After': String(rl.retryAfterSec) } },
      );
    }
    const request = await parseJsonBody(req, planRequestSchema);
    const program = await generateProgram(userId, buildPlanGoal(request));
    return NextResponse.json({ program });
  } catch (err) {
    if (err instanceof LlmError) {
      return NextResponse.json({ error: err.message }, { status: err.status });
    }
    return handleApiError(err);
  }
}
