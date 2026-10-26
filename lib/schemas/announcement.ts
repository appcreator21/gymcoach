import { z } from 'zod';

export const announcementInputSchema = z.object({
  title: z.string().trim().min(1, 'Title required').max(120, 'Too long'),
  body: z.string().trim().min(1, 'Message required').max(2000, 'Too long'),
  pinned: z.boolean().optional().default(false),
});

export type AnnouncementInput = z.infer<typeof announcementInputSchema>;
