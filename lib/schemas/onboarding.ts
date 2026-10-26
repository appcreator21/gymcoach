import { z } from 'zod';
import { Sex, TrainingGoal, WeightUnit } from '@/lib/prisma-client';

export const FOCUS_AREAS = [
  'Chest',
  'Back',
  'Shoulders',
  'Arms',
  'Legs',
  'Glutes',
  'Core',
] as const;

// Intake questionnaire a new client answers right after creating an account.
// Everything but the name and goal is bounded free choice, so the answers are
// safe to embed in the coach prompt.
export const onboardingSchema = z.object({
  displayName: z.string().trim().min(1).max(80),
  sex: z.nativeEnum(Sex).optional(),
  age: z.number().int().min(13).max(100).optional(),
  heightCm: z.number().int().min(100).max(250).optional(),
  bodyweightKg: z.number().min(20).max(300).optional(),
  unit: z.nativeEnum(WeightUnit).default('KG'),
  goal: z.nativeEnum(TrainingGoal),
  motivation: z.string().trim().max(300).optional(),
  experience: z.enum(['NEW', 'SOME', 'EXPERIENCED', 'ADVANCED']),
  daysPerWeek: z.number().int().min(1).max(7),
  sessionMinutes: z.number().int().min(20).max(150),
  location: z.enum(['COMMERCIAL_GYM', 'HOME_GYM', 'MINIMAL', 'BODYWEIGHT']),
  focusAreas: z.array(z.enum(FOCUS_AREAS)).max(FOCUS_AREAS.length).default([]),
  injuries: z.string().trim().max(500).optional(),
  dislikes: z.string().trim().max(300).optional(),
  sleepHours: z.enum(['UNDER_5', 'FIVE_TO_6', 'SEVEN_TO_8', 'OVER_8']).optional(),
  lifestyle: z.enum(['DESK', 'MIXED', 'ON_FEET', 'PHYSICAL']).optional(),
  coachingStyle: z.enum(['PUSH_ME', 'SUPPORTIVE', 'DATA_DRIVEN', 'RELAXED']).default('SUPPORTIVE'),
});

export type OnboardingAnswers = z.infer<typeof onboardingSchema>;
