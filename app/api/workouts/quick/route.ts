import { NextResponse } from 'next/server';
import { handleApiError, parseJsonBody, requireApiUserId } from '@/lib/api';
import { LlmError } from '@/lib/llm';
import { rateLimit } from '@/lib/rate-limit';
import { createQuickWorkout } from '@/lib/quick-workout';
import { quickWorkoutRequestSchema } from '@/lib/schemas/plan-request';

// POST /api/workouts/quick: builds a one-off workout for the equipment, time
// and focus the user has right now and returns where it was saved.
export async function POST(req: Request) {
  try {
    const userId = await requireApiUserId();
    const rl = rateLimit(`quick:${userId}`, 8, 60_000);
    if (!rl.ok) {
      return NextResponse.json(
        { error: 'Too many requests. Please wait a moment.' },
        { status: 429, headers: { 'Retry-After': String(rl.retryAfterSec) } },
      );
    }
    const request = await parseJsonBody(req, quickWorkoutRequestSchema);
    const saved = await createQuickWorkout(userId, request);
    return NextResponse.json(saved, { status: 201 });
  } catch (err) {
    if (err instanceof LlmError) {
      return NextResponse.json({ error: err.message }, { status: err.status });
    }
    return handleApiError(err);
  }
}
