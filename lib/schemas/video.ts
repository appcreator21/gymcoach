import { z } from 'zod';
import { STORAGE_KEY_PATTERN } from '@/lib/storage';

export const VIDEO_CATEGORIES = ['Workouts', 'Technique', 'Tips', 'Mobility', 'Nutrition', 'Motivation'] as const;

// Only https links: the app plays them directly, and a plain http or custom
// scheme link has no place in a published video.
const httpsUrl = z
  .string()
  .trim()
  .max(2000)
  .refine((value) => {
    try {
      return new URL(value).protocol === 'https:';
    } catch {
      return false;
    }
  }, 'Use a full https link.');

const emptyToNull = (v: unknown) => (typeof v === 'string' && v.trim() === '' ? null : v);

export const videoInputSchema = z.object({
  title: z.string().trim().min(1, 'Title required').max(120),
  description: z.preprocess(emptyToNull, z.string().trim().max(2000).nullable().optional()),
  videoUrl: httpsUrl,
  thumbnailUrl: z.preprocess(emptyToNull, httpsUrl.nullable().optional()),
  category: z.string().trim().min(1).max(40).default('Workouts'),
  exerciseName: z.preprocess(emptyToNull, z.string().trim().max(120).nullable().optional()),
  workoutName: z.preprocess(emptyToNull, z.string().trim().max(120).nullable().optional()),
  // Set by the app after an upload. Absent leaves the stored keys alone.
  storageKey: z.string().regex(STORAGE_KEY_PATTERN).nullable().optional(),
  thumbnailKey: z.string().regex(STORAGE_KEY_PATTERN).nullable().optional(),
  durationSec: z.preprocess(emptyToNull, z.coerce.number().int().min(1).max(14_400).nullable().optional()),
  featured: z.boolean().optional().default(false),
});

export type VideoInput = z.infer<typeof videoInputSchema>;

// Lower-cased, punctuation-free form used to match a video to an exercise.
export function normalizeExerciseName(name: string): string {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
}
