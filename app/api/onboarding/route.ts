import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { handleApiError, parseJsonBody, requireApiUserId } from '@/lib/api';
import { onboardingSchema } from '@/lib/schemas/onboarding';
import { buildInitialMemory } from '@/lib/memory';

// POST /api/onboarding: saves the intake answers, mirrors the structured ones
// onto the profile, and seeds the client's memory file.
export async function POST(req: Request) {
  try {
    const userId = await requireApiUserId();
    const a = await parseJsonBody(req, onboardingSchema);
    const now = new Date();

    const updated = await db.user.update({
      where: { id: userId },
      data: {
        displayName: a.displayName,
        sex: a.sex ?? null,
        heightCm: a.heightCm ?? null,
        bodyweight: a.bodyweightKg ?? null,
        goal: a.goal,
        weeklyFrequency: a.daysPerWeek,
        unit: a.unit,
        coachNote: a.injuries ? a.injuries : null,
        onboarding: a,
        onboardedAt: now,
        memory: buildInitialMemory(a),
        memoryUpdatedAt: now,
      },
      select: { onboardedAt: true },
    });
    if (a.bodyweightKg) {
      await db.bodyweightEntry
        .create({ data: { userId, weightKg: a.bodyweightKg, note: 'Onboarding' } })
        .catch(() => {});
    }
    return NextResponse.json(updated);
  } catch (err) {
    return handleApiError(err);
  }
}
