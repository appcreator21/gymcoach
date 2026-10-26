import type { PlanRequest, QuickWorkoutRequest } from '@/lib/schemas/plan-request';

// Turns a structured request into the natural-language goal the program
// generator already understands. Pure, so it is unit tested.

const STYLE_TEXT: Record<PlanRequest['style'], string> = {
  HYPERTROPHY: 'muscle growth (hypertrophy) with moderate reps and enough weekly volume per muscle',
  STRENGTH: 'maximal strength with heavy compound lifts, lower reps and long rests',
  POWERLIFTING: 'powerlifting: squat, bench press and deadlift focus with accessory work and heavy singles to fives',
  BODYWEIGHT: 'calisthenics and bodyweight strength with progressions instead of added load',
  SCULPT: 'fat loss and a lean, sculpted look: full body training, supersets, short rests and some conditioning',
  GENERAL: 'general fitness: balanced strength, muscle and conditioning',
};

const EQUIPMENT_TEXT: Record<PlanRequest['equipment'], string> = {
  FULL_GYM: 'a fully equipped commercial gym (barbells, dumbbells, machines, cables)',
  HOME_DUMBBELLS: 'a home setup with adjustable dumbbells and a bench only',
  HOME_MINIMAL: 'a minimal home setup: resistance bands and a pair of light dumbbells',
  HOTEL: 'a hotel gym: dumbbells up to moderate weight, a cable stack or Smith machine, and a treadmill',
  BODYWEIGHT: 'no equipment at all: bodyweight only, plus a sturdy chair or table',
};

const FOCUS_TEXT: Record<QuickWorkoutRequest['focus'], string> = {
  FULL_BODY: 'a full body session',
  UPPER: 'an upper body session',
  LOWER: 'a lower body session',
  PUSH: 'a push session (chest, shoulders, triceps)',
  PULL: 'a pull session (back, rear delts, biceps)',
  LEGS: 'a leg session',
  CORE: 'a core and abs session',
  ARMS_SHOULDERS: 'an arms and shoulders session',
  GLUTES: 'a glute focused session',
};

const INTENSITY_TEXT: Record<QuickWorkoutRequest['intensity'], string> = {
  LIGHT: 'Keep it light and easy: low fatigue, stop sets well short of failure.',
  NORMAL: 'Normal training intensity.',
  HARD: 'Make it hard: push sets close to failure and keep rests short.',
};

export function buildPlanGoal(req: PlanRequest): string {
  const lines = [
    `Design a ${req.daysPerWeek} day per week program focused on ${STYLE_TEXT[req.style]}.`,
    `Each session must fit in about ${req.sessionMinutes} minutes.`,
    `Equipment available: ${EQUIPMENT_TEXT[req.equipment]}. Use only exercises that equipment allows.`,
  ];
  if (req.focusAreas.length > 0) {
    lines.push(`Give extra weekly volume to: ${req.focusAreas.join(', ')}.`);
  }
  if (req.notes) lines.push(`Extra notes from the trainee: ${req.notes}`);
  return lines.join('\n');
}

export function buildQuickWorkoutGoal(req: QuickWorkoutRequest): string {
  const lines = [
    `Create exactly ONE workout (a program with a single workout): ${FOCUS_TEXT[req.focus]} that takes about ${req.minutes} minutes including rest.`,
    `Equipment available: ${EQUIPMENT_TEXT[req.equipment]}. Use only exercises that equipment allows.`,
    INTENSITY_TEXT[req.intensity],
    'Name the workout so it says what it is (for example "Quick Upper, 30 min").',
  ];
  if (req.notes) lines.push(`Extra notes from the trainee: ${req.notes}`);
  return lines.join('\n');
}

// Rough number of exercises that fit a time box, used to sanity check output.
export function expectedExerciseRange(minutes: number): { min: number; max: number } {
  return { min: Math.max(2, Math.floor(minutes / 12)), max: Math.max(4, Math.ceil(minutes / 5)) };
}
