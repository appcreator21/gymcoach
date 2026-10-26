import { z } from 'zod';

export const sessionStartSchema = z.object({
  workoutId: z.string().min(1),
  gymId: z.string().min(1).optional().nullable(),
});

export const sessionUpdateSchema = z
  .object({
    // Undefined leaves the notes alone; null or an empty string clears them.
    notes: z.string().trim().max(2000).optional().nullable(),
    // Clock actions (lib/session-clock.ts). At most one per request.
    finish: z.boolean().optional(),
    pause: z.boolean().optional(),
    resume: z.boolean().optional(),
    reopen: z.boolean().optional(),
  })
  .refine(
    (v) => [v.finish, v.pause, v.resume, v.reopen].filter((flag) => flag === true).length <= 1,
    { message: 'Send one action at a time.' },
  );

export type SessionStart = z.infer<typeof sessionStartSchema>;
export type SessionUpdate = z.infer<typeof sessionUpdateSchema>;
