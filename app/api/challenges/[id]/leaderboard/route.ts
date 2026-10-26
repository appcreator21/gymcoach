import { NextResponse } from 'next/server';
import { db } from '@/lib/db';
import { ApiError, handleApiError, requireApiUserId } from '@/lib/api';
import { buildLeaderboard, publicName, scoreParticipants } from '@/lib/challenges';

// GET /api/challenges/[id]/leaderboard: ranked participants, scored from
// finished sessions inside the challenge window.
export async function GET(_req: Request, props: { params: Promise<{ id: string }> }) {
  const params = await props.params;
  try {
    const userId = await requireApiUserId();
    const challenge = await db.challenge.findUnique({
      where: { id: params.id },
      include: { entries: { select: { user: { select: { id: true, displayName: true } } } } },
    });
    if (!challenge) throw new ApiError(404, 'Challenge not found.');

    const participantIds = challenge.entries.map((e) => e.user.id);
    const names = new Map(challenge.entries.map((e) => [e.user.id, publicName(e.user.displayName)]));
    const window = { gte: challenge.startsAt, lte: challenge.endsAt };

    const [sessions, sets] =
      participantIds.length === 0
        ? [[], []]
        : await Promise.all([
            db.session.findMany({
              where: { userId: { in: participantIds }, finishedAt: window },
              select: { userId: true },
            }),
            challenge.metric === 'WORKOUTS'
              ? Promise.resolve([])
              : db.set
                  .findMany({
                    where: {
                      isWarmup: false,
                      session: { userId: { in: participantIds }, finishedAt: window },
                    },
                    select: {
                      weight: true,
                      reps: true,
                      isWarmup: true,
                      durationSec: true,
                      session: { select: { userId: true } },
                    },
                  })
                  .then((rows) =>
                    rows.map((r) => ({
                      userId: r.session.userId,
                      weight: r.weight,
                      reps: r.reps,
                      isWarmup: r.isWarmup,
                      durationSec: r.durationSec,
                    })),
                  ),
          ]);

    const rows = buildLeaderboard(scoreParticipants(challenge.metric, participantIds, sessions, sets), names);
    const me = rows.find((r) => r.userId === userId);
    return NextResponse.json({
      metric: challenge.metric,
      rows: rows.slice(0, 50).map((r) => ({ name: r.name, score: r.score, rank: r.rank, isMe: r.userId === userId })),
      myRank: me?.rank ?? null,
      participants: rows.length,
    });
  } catch (err) {
    return handleApiError(err);
  }
}
