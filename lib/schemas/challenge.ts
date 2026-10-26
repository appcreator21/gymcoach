import { z } from 'zod';

export const challengeInputSchema = z
  .object({
    title: z.string().trim().min(1, 'Title required').max(80),
    description: z.string().trim().max(500).optional().nullable(),
    metric: z.enum(['WORKOUTS', 'SETS', 'VOLUME']),
    startsAt: z.coerce.date(),
    endsAt: z.coerce.date(),
  })
  .refine((c) => c.endsAt > c.startsAt, { message: 'The end must be after the start.', path: ['endsAt'] });

export type ChallengeInput = z.infer<typeof challengeInputSchema>;
