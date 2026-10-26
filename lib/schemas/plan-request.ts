import { z } from 'zod';

export const PLAN_STYLES = [
  'HYPERTROPHY',
  'STRENGTH',
  'POWERLIFTING',
  'BODYWEIGHT',
  'SCULPT',
  'GENERAL',
] as const;

export const EQUIPMENT_PROFILES = [
  'FULL_GYM',
  'HOME_DUMBBELLS',
  'HOME_MINIMAL',
  'HOTEL',
  'BODYWEIGHT',
] as const;

export const QUICK_FOCUS = [
  'FULL_BODY',
  'UPPER',
  'LOWER',
  'PUSH',
  'PULL',
  'LEGS',
  'CORE',
  'ARMS_SHOULDERS',
  'GLUTES',
] as const;

export const FOCUS_AREAS_PLAN = ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Glutes', 'Core'] as const;

// A self-serve plan request: bounded choices, so the text built from it is
// safe to put in the model prompt. Free text is length capped.
export const planRequestSchema = z.object({
  style: z.enum(PLAN_STYLES),
  daysPerWeek: z.number().int().min(1).max(7),
  sessionMinutes: z.number().int().min(15).max(150),
  equipment: z.enum(EQUIPMENT_PROFILES),
  focusAreas: z.array(z.enum(FOCUS_AREAS_PLAN)).max(FOCUS_AREAS_PLAN.length).default([]),
  notes: z.string().trim().max(500).optional(),
});

export const quickWorkoutRequestSchema = z.object({
  equipment: z.enum(EQUIPMENT_PROFILES),
  minutes: z.number().int().min(10).max(120),
  focus: z.enum(QUICK_FOCUS),
  intensity: z.enum(['LIGHT', 'NORMAL', 'HARD']).default('NORMAL'),
  notes: z.string().trim().max(300).optional(),
});

export type PlanRequest = z.infer<typeof planRequestSchema>;
export type QuickWorkoutRequest = z.infer<typeof quickWorkoutRequestSchema>;
