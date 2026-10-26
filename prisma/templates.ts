import type { GeneratedProgram } from '@/lib/schemas/program-generation';

// Starter program templates for the admin portal. They are seeded into the
// ProgramTemplate table (prisma/seed-templates.ts) and live in the database
// from then on, so an admin can edit or delete them in the app. Nothing reads
// this file at runtime.

type Muscle =
  | 'CHEST'
  | 'BACK_WIDTH'
  | 'BACK_THICKNESS'
  | 'SHOULDERS_FRONT'
  | 'SHOULDERS_LATERAL'
  | 'SHOULDERS_REAR'
  | 'BICEPS'
  | 'TRICEPS'
  | 'FOREARMS'
  | 'QUADS'
  | 'HAMSTRINGS'
  | 'GLUTES'
  | 'CALVES'
  | 'ABS'
  | 'LOWER_BACK';
type Equipment = 'DUMBBELL' | 'BARBELL' | 'MACHINE' | 'CABLE' | 'BODYWEIGHT' | 'OTHER';

interface Move {
  name: string;
  muscleGroup: Muscle;
  category: 'COMPOUND' | 'ISOLATION';
  equipmentType: Equipment;
}

const m = (
  name: string,
  muscleGroup: Muscle,
  category: Move['category'],
  equipmentType: Equipment,
): Move => ({ name, muscleGroup, category, equipmentType });

// Names that exist in the default catalog match it exactly, so assigning a
// template reuses the client's existing exercises.
const L = {
  bench: m('Barbell bench press', 'CHEST', 'COMPOUND', 'BARBELL'),
  inclineDb: m('Incline dumbbell press (30 deg)', 'CHEST', 'COMPOUND', 'DUMBBELL'),
  flatDb: m('Flat dumbbell bench press', 'CHEST', 'COMPOUND', 'DUMBBELL'),
  machineChest: m('Machine chest press', 'CHEST', 'COMPOUND', 'MACHINE'),
  fly: m('Pec deck (or cable fly)', 'CHEST', 'ISOLATION', 'MACHINE'),
  dips: m('Machine dips or parallel bars', 'TRICEPS', 'COMPOUND', 'MACHINE'),
  pullUp: m('Pronated pull-ups (weighted if possible)', 'BACK_WIDTH', 'COMPOUND', 'BODYWEIGHT'),
  pulldown: m('Lat pulldown (wide grip)', 'BACK_WIDTH', 'COMPOUND', 'CABLE'),
  neutralPulldown: m('Neutral-grip lat pulldown', 'BACK_WIDTH', 'COMPOUND', 'CABLE'),
  bbRow: m('Bent-over barbell row', 'BACK_THICKNESS', 'COMPOUND', 'BARBELL'),
  cableRow: m('Seated cable row (close handles)', 'BACK_THICKNESS', 'COMPOUND', 'CABLE'),
  csRow: m('Chest-supported machine row', 'BACK_THICKNESS', 'COMPOUND', 'MACHINE'),
  dbRow: m('Single-arm dumbbell row', 'BACK_THICKNESS', 'COMPOUND', 'DUMBBELL'),
  ohp: m('Standing barbell overhead press', 'SHOULDERS_FRONT', 'COMPOUND', 'BARBELL'),
  dbPress: m('Seated dumbbell overhead press', 'SHOULDERS_FRONT', 'COMPOUND', 'DUMBBELL'),
  lateral: m('Dumbbell lateral raise', 'SHOULDERS_LATERAL', 'ISOLATION', 'DUMBBELL'),
  cableLateral: m('Cable lateral raises', 'SHOULDERS_LATERAL', 'ISOLATION', 'CABLE'),
  facePull: m('Face pull (rope)', 'SHOULDERS_REAR', 'ISOLATION', 'CABLE'),
  rearFly: m('Machine rear delt fly', 'SHOULDERS_REAR', 'ISOLATION', 'MACHINE'),
  ezCurl: m('EZ-bar curl', 'BICEPS', 'ISOLATION', 'BARBELL'),
  inclineCurl: m('Incline dumbbell curl (bench 60 deg)', 'BICEPS', 'ISOLATION', 'DUMBBELL'),
  hammer: m('Hammer curl (dumbbell)', 'BICEPS', 'ISOLATION', 'DUMBBELL'),
  pushdown: m('Triceps pushdown (rope)', 'TRICEPS', 'ISOLATION', 'CABLE'),
  ohTri: m('Overhead cable triceps extension', 'TRICEPS', 'ISOLATION', 'CABLE'),
  skull: m('EZ-bar skull crusher', 'TRICEPS', 'ISOLATION', 'BARBELL'),
  cgBench: m('Close-grip bench press', 'TRICEPS', 'COMPOUND', 'BARBELL'),
  squat: m('Barbell back squat', 'QUADS', 'COMPOUND', 'BARBELL'),
  hackSquat: m('Machine squat (or Hack squat)', 'QUADS', 'COMPOUND', 'MACHINE'),
  legPress: m('Leg press (45 deg)', 'QUADS', 'COMPOUND', 'MACHINE'),
  goblet: m('Goblet squat', 'QUADS', 'COMPOUND', 'DUMBBELL'),
  bulgarian: m('Bulgarian split squat', 'QUADS', 'COMPOUND', 'DUMBBELL'),
  lunge: m('Walking lunges with dumbbells', 'QUADS', 'COMPOUND', 'DUMBBELL'),
  legExt: m('Leg extension', 'QUADS', 'ISOLATION', 'MACHINE'),
  deadlift: m('Conventional deadlift', 'BACK_THICKNESS', 'COMPOUND', 'BARBELL'),
  rdl: m('Dumbbell Romanian Deadlift', 'HAMSTRINGS', 'COMPOUND', 'DUMBBELL'),
  bbRdl: m('Barbell Romanian deadlift', 'HAMSTRINGS', 'COMPOUND', 'BARBELL'),
  legCurl: m('Seated leg curl', 'HAMSTRINGS', 'ISOLATION', 'MACHINE'),
  thrust: m('Barbell hip thrust (or machine)', 'GLUTES', 'COMPOUND', 'BARBELL'),
  kickback: m('Cable glute kickback', 'GLUTES', 'ISOLATION', 'CABLE'),
  abduction: m('Hip abduction machine', 'GLUTES', 'ISOLATION', 'MACHINE'),
  calf: m('Standing calf raise (or machine)', 'CALVES', 'ISOLATION', 'MACHINE'),
  cableCrunch: m('Cable crunch (kneeling)', 'ABS', 'ISOLATION', 'CABLE'),
  legRaise: m('Hanging leg raises', 'ABS', 'ISOLATION', 'BODYWEIGHT'),
  plank: m('Plank + side plank', 'ABS', 'ISOLATION', 'BODYWEIGHT'),
  backExt: m('Back extension (hyperextension)', 'LOWER_BACK', 'ISOLATION', 'BODYWEIGHT'),
  pushUp: m('Push-ups', 'CHEST', 'COMPOUND', 'BODYWEIGHT'),
  invRow: m('Inverted row', 'BACK_THICKNESS', 'COMPOUND', 'BODYWEIGHT'),
  pike: m('Pike push-up', 'SHOULDERS_FRONT', 'COMPOUND', 'BODYWEIGHT'),
  bwSquat: m('Bodyweight squat', 'QUADS', 'COMPOUND', 'BODYWEIGHT'),
  glute: m('Glute bridge', 'GLUTES', 'COMPOUND', 'BODYWEIGHT'),
  stepUp: m('Dumbbell step-up', 'QUADS', 'COMPOUND', 'DUMBBELL'),
  dbCurl: m('Dumbbell curl', 'BICEPS', 'ISOLATION', 'DUMBBELL'),
  dbTri: m('Dumbbell overhead triceps extension', 'TRICEPS', 'ISOLATION', 'DUMBBELL'),
} satisfies Record<string, Move>;

type Key = keyof typeof L;

// [exercise, sets, repsMin, repsMax, RIR, rest seconds]
type Row = [Key, number, number, number, number, number];

const day = (name: string, dayOfWeek: number, rows: Row[]) => ({
  name,
  dayOfWeek,
  exercises: rows.map(([key, sets, min, max, rir, rest]) => ({
    ...L[key],
    targetSets: sets,
    targetRepsMin: min,
    targetRepsMax: max,
    targetRIR: rir,
    restSec: rest,
  })),
});

export const PROGRAM_TEMPLATES: GeneratedProgram[] = [
  {
    name: 'Beginner Full Body (3 days)',
    description: 'Three simple full-body sessions a week. Learn the main lifts and build a base.',
    phase: 'Beginner',
    workouts: [
      day('Full Body A', 1, [
        ['goblet', 3, 8, 12, 3, 90],
        ['machineChest', 3, 8, 12, 3, 90],
        ['cableRow', 3, 8, 12, 3, 90],
        ['rdl', 2, 8, 12, 3, 90],
        ['cableLateral', 2, 12, 15, 2, 60],
        ['plank', 2, 30, 45, 2, 60],
      ]),
      day('Full Body B', 3, [
        ['legPress', 3, 8, 12, 3, 90],
        ['dbPress', 3, 8, 12, 3, 90],
        ['neutralPulldown', 3, 8, 12, 3, 90],
        ['legCurl', 2, 10, 15, 3, 60],
        ['hammer', 2, 10, 15, 2, 60],
        ['pushdown', 2, 10, 15, 2, 60],
      ]),
      day('Full Body C', 5, [
        ['hackSquat', 3, 8, 12, 3, 90],
        ['inclineDb', 3, 8, 12, 3, 90],
        ['csRow', 3, 8, 12, 3, 90],
        ['thrust', 3, 8, 12, 3, 90],
        ['facePull', 2, 12, 15, 2, 60],
        ['cableCrunch', 2, 10, 15, 2, 60],
      ]),
    ],
  },
  {
    name: 'Upper / Lower Hypertrophy (4 days)',
    description:
      'Classic four-day split. Each muscle trains twice a week with a heavy and a volume day.',
    phase: 'Hypertrophy',
    workouts: [
      day('Upper A', 1, [
        ['bench', 4, 6, 8, 2, 150],
        ['bbRow', 4, 6, 8, 2, 150],
        ['dbPress', 3, 8, 10, 2, 120],
        ['pulldown', 3, 8, 12, 2, 90],
        ['ezCurl', 3, 8, 12, 1, 75],
        ['pushdown', 3, 8, 12, 1, 75],
      ]),
      day('Lower A', 2, [
        ['squat', 4, 6, 8, 2, 180],
        ['rdl', 3, 8, 10, 2, 120],
        ['legPress', 3, 10, 12, 2, 120],
        ['legCurl', 3, 10, 12, 1, 75],
        ['calf', 4, 10, 15, 1, 60],
        ['legRaise', 3, 10, 15, 1, 60],
      ]),
      day('Upper B', 4, [
        ['ohp', 4, 6, 8, 2, 150],
        ['pullUp', 4, 6, 10, 2, 120],
        ['inclineDb', 3, 8, 12, 2, 90],
        ['cableRow', 3, 8, 12, 2, 90],
        ['lateral', 4, 12, 15, 1, 60],
        ['inclineCurl', 3, 10, 12, 1, 75],
        ['ohTri', 3, 10, 12, 1, 75],
      ]),
      day('Lower B', 5, [
        ['hackSquat', 4, 8, 10, 2, 150],
        ['bbRdl', 3, 8, 10, 2, 150],
        ['bulgarian', 3, 8, 12, 2, 120],
        ['legExt', 3, 12, 15, 1, 75],
        ['thrust', 3, 8, 12, 1, 90],
        ['calf', 4, 10, 15, 1, 60],
      ]),
    ],
  },
  {
    name: 'Push Pull Legs (6 days)',
    description: 'High-frequency split for experienced lifters: every muscle twice a week.',
    phase: 'Hypertrophy',
    workouts: [
      day('Push A', 1, [
        ['bench', 4, 6, 8, 2, 150],
        ['dbPress', 3, 8, 10, 2, 120],
        ['inclineDb', 3, 8, 12, 2, 90],
        ['cableLateral', 4, 12, 15, 1, 60],
        ['pushdown', 3, 10, 12, 1, 60],
      ]),
      day('Pull A', 2, [
        ['pullUp', 4, 6, 10, 2, 120],
        ['bbRow', 4, 6, 8, 2, 150],
        ['cableRow', 3, 8, 12, 2, 90],
        ['facePull', 3, 12, 15, 1, 60],
        ['ezCurl', 3, 8, 12, 1, 60],
      ]),
      day('Legs A', 3, [
        ['squat', 4, 6, 8, 2, 180],
        ['rdl', 3, 8, 10, 2, 120],
        ['legPress', 3, 10, 12, 2, 120],
        ['legCurl', 3, 10, 12, 1, 75],
        ['calf', 4, 10, 15, 1, 60],
      ]),
      day('Push B', 4, [
        ['ohp', 4, 6, 8, 2, 150],
        ['machineChest', 3, 8, 12, 2, 90],
        ['fly', 3, 12, 15, 1, 60],
        ['lateral', 4, 12, 15, 1, 60],
        ['skull', 3, 10, 12, 1, 60],
      ]),
      day('Pull B', 5, [
        ['neutralPulldown', 4, 8, 12, 2, 90],
        ['dbRow', 3, 8, 12, 2, 90],
        ['csRow', 3, 10, 12, 2, 90],
        ['rearFly', 3, 12, 15, 1, 60],
        ['hammer', 3, 10, 12, 1, 60],
      ]),
      day('Legs B', 6, [
        ['hackSquat', 4, 8, 10, 2, 150],
        ['bbRdl', 3, 8, 10, 2, 150],
        ['lunge', 3, 10, 12, 2, 90],
        ['legExt', 3, 12, 15, 1, 60],
        ['thrust', 3, 8, 12, 1, 90],
        ['cableCrunch', 3, 10, 15, 1, 60],
      ]),
    ],
  },
  {
    name: 'Push Pull Legs (3 days)',
    description: 'One push, one pull and one leg day a week. Efficient when time is tight.',
    phase: 'General',
    workouts: [
      day('Push', 1, [
        ['bench', 4, 6, 10, 2, 120],
        ['dbPress', 3, 8, 12, 2, 90],
        ['inclineDb', 3, 8, 12, 2, 90],
        ['lateral', 3, 12, 15, 1, 60],
        ['pushdown', 3, 10, 12, 1, 60],
      ]),
      day('Pull', 3, [
        ['pullUp', 4, 6, 10, 2, 120],
        ['bbRow', 3, 8, 10, 2, 120],
        ['cableRow', 3, 10, 12, 2, 90],
        ['facePull', 3, 12, 15, 1, 60],
        ['ezCurl', 3, 8, 12, 1, 60],
      ]),
      day('Legs', 5, [
        ['squat', 4, 6, 10, 2, 150],
        ['rdl', 3, 8, 10, 2, 120],
        ['legPress', 3, 10, 12, 2, 90],
        ['legCurl', 3, 10, 12, 1, 60],
        ['calf', 4, 10, 15, 1, 60],
      ]),
    ],
  },
  {
    name: 'Strength Base (3 days)',
    description:
      'Low reps on the big barbell lifts with long rests. Add weight when the top of the range is hit.',
    phase: 'Strength',
    workouts: [
      day('Squat + Press', 1, [
        ['squat', 5, 3, 5, 2, 210],
        ['bench', 4, 4, 6, 2, 180],
        ['bbRow', 3, 5, 8, 2, 150],
        ['plank', 3, 30, 50, 2, 60],
      ]),
      day('Deadlift + Press', 3, [
        ['deadlift', 4, 3, 5, 2, 240],
        ['ohp', 4, 4, 6, 2, 180],
        ['pullUp', 4, 4, 8, 2, 150],
        ['legRaise', 3, 8, 12, 2, 60],
      ]),
      day('Volume Day', 5, [
        ['squat', 3, 6, 8, 3, 180],
        ['cgBench', 4, 5, 8, 2, 150],
        ['cableRow', 3, 8, 10, 2, 120],
        ['bbRdl', 3, 6, 8, 2, 150],
      ]),
    ],
  },
  {
    name: 'Bro Split (5 days)',
    description: 'One muscle group per day with plenty of isolation volume.',
    phase: 'Hypertrophy',
    workouts: [
      day('Chest', 1, [
        ['bench', 4, 6, 10, 2, 120],
        ['inclineDb', 4, 8, 12, 2, 90],
        ['machineChest', 3, 10, 12, 1, 75],
        ['fly', 3, 12, 15, 1, 60],
      ]),
      day('Back', 2, [
        ['pullUp', 4, 6, 10, 2, 120],
        ['bbRow', 4, 8, 10, 2, 120],
        ['cableRow', 3, 10, 12, 2, 90],
        ['dbRow', 3, 10, 12, 1, 75],
        ['facePull', 3, 12, 15, 1, 60],
      ]),
      day('Shoulders', 3, [
        ['ohp', 4, 6, 10, 2, 120],
        ['lateral', 4, 12, 15, 1, 60],
        ['cableLateral', 3, 12, 15, 1, 60],
        ['rearFly', 4, 12, 15, 1, 60],
      ]),
      day('Legs', 4, [
        ['squat', 4, 6, 10, 2, 180],
        ['legPress', 3, 10, 12, 2, 120],
        ['legCurl', 4, 10, 12, 1, 75],
        ['legExt', 3, 12, 15, 1, 60],
        ['calf', 5, 10, 15, 1, 60],
      ]),
      day('Arms', 5, [
        ['ezCurl', 4, 8, 12, 1, 75],
        ['skull', 4, 8, 12, 1, 75],
        ['inclineCurl', 3, 10, 12, 1, 60],
        ['ohTri', 3, 10, 12, 1, 60],
        ['hammer', 3, 10, 12, 1, 60],
      ]),
    ],
  },
  {
    name: 'Glute Focus (4 days)',
    description: 'Glute and leg emphasis with upper-body maintenance.',
    phase: 'Hypertrophy',
    workouts: [
      day('Glutes + Hamstrings', 1, [
        ['thrust', 4, 8, 12, 2, 120],
        ['bbRdl', 4, 8, 10, 2, 120],
        ['bulgarian', 3, 8, 12, 2, 90],
        ['legCurl', 3, 10, 15, 1, 60],
        ['abduction', 3, 12, 20, 1, 60],
      ]),
      day('Upper Body', 2, [
        ['dbPress', 3, 8, 12, 2, 90],
        ['pulldown', 3, 8, 12, 2, 90],
        ['inclineDb', 3, 8, 12, 2, 90],
        ['cableRow', 3, 8, 12, 2, 90],
        ['cableLateral', 3, 12, 15, 1, 60],
      ]),
      day('Quads + Glutes', 4, [
        ['squat', 4, 6, 10, 2, 150],
        ['legPress', 3, 10, 15, 2, 120],
        ['lunge', 3, 10, 12, 2, 90],
        ['kickback', 3, 12, 15, 1, 60],
        ['calf', 4, 10, 15, 1, 60],
      ]),
      day('Glutes + Core', 5, [
        ['thrust', 4, 10, 15, 2, 90],
        ['backExt', 3, 10, 15, 2, 75],
        ['abduction', 3, 15, 20, 1, 45],
        ['kickback', 3, 12, 15, 1, 45],
        ['cableCrunch', 3, 10, 15, 1, 60],
      ]),
    ],
  },
  {
    name: 'Home Dumbbell Full Body (3 days)',
    description: 'A pair of dumbbells and a bench is enough. Three full-body days.',
    phase: 'General',
    workouts: [
      day('Day 1', 1, [
        ['goblet', 3, 8, 12, 2, 90],
        ['flatDb', 3, 8, 12, 2, 90],
        ['dbRow', 3, 8, 12, 2, 90],
        ['rdl', 3, 8, 12, 2, 90],
        ['lateral', 2, 12, 15, 1, 60],
      ]),
      day('Day 2', 3, [
        ['bulgarian', 3, 8, 12, 2, 90],
        ['dbPress', 3, 8, 12, 2, 90],
        ['dbRow', 3, 10, 12, 2, 90],
        ['glute', 3, 12, 15, 2, 60],
        ['dbCurl', 2, 10, 15, 1, 60],
        ['dbTri', 2, 10, 15, 1, 60],
      ]),
      day('Day 3', 5, [
        ['stepUp', 3, 8, 12, 2, 90],
        ['inclineDb', 3, 8, 12, 2, 90],
        ['dbRow', 3, 8, 12, 2, 90],
        ['rdl', 3, 10, 12, 2, 90],
        ['hammer', 2, 10, 15, 1, 60],
        ['plank', 2, 30, 45, 2, 45],
      ]),
    ],
  },
  {
    name: 'Bodyweight Basics (3 days)',
    description:
      'No equipment needed. Progress by adding reps, slowing the tempo or making moves harder.',
    phase: 'Beginner',
    workouts: [
      day('Day 1', 1, [
        ['pushUp', 3, 8, 15, 2, 60],
        ['bwSquat', 3, 12, 20, 2, 60],
        ['invRow', 3, 8, 12, 2, 60],
        ['glute', 3, 12, 20, 2, 45],
        ['plank', 3, 30, 45, 2, 45],
      ]),
      day('Day 2', 3, [
        ['pike', 3, 6, 12, 2, 60],
        ['lunge', 3, 10, 12, 2, 60],
        ['invRow', 3, 8, 12, 2, 60],
        ['pushUp', 2, 8, 15, 2, 60],
        ['legRaise', 3, 8, 12, 2, 45],
      ]),
      day('Day 3', 5, [
        ['bwSquat', 4, 15, 25, 2, 45],
        ['pushUp', 3, 8, 15, 2, 60],
        ['glute', 3, 15, 20, 2, 45],
        ['invRow', 3, 8, 12, 2, 60],
        ['plank', 3, 30, 50, 2, 45],
      ]),
    ],
  },
  {
    name: 'Fat Loss Full Body (4 days)',
    description: 'Higher reps and shorter rests to keep intensity up while eating in a deficit.',
    phase: 'Fat loss',
    workouts: [
      day('Full Body 1', 1, [
        ['goblet', 3, 10, 15, 2, 60],
        ['machineChest', 3, 10, 15, 2, 60],
        ['cableRow', 3, 10, 15, 2, 60],
        ['rdl', 3, 10, 12, 2, 75],
        ['cableCrunch', 3, 12, 15, 1, 45],
      ]),
      day('Full Body 2', 2, [
        ['legPress', 3, 12, 15, 2, 60],
        ['dbPress', 3, 10, 15, 2, 60],
        ['neutralPulldown', 3, 10, 15, 2, 60],
        ['legCurl', 3, 12, 15, 1, 45],
        ['lateral', 3, 12, 20, 1, 45],
      ]),
      day('Full Body 3', 4, [
        ['lunge', 3, 10, 12, 2, 60],
        ['inclineDb', 3, 10, 15, 2, 60],
        ['csRow', 3, 10, 15, 2, 60],
        ['thrust', 3, 10, 15, 2, 60],
        ['legRaise', 3, 10, 15, 1, 45],
      ]),
      day('Full Body 4', 5, [
        ['hackSquat', 3, 10, 15, 2, 60],
        ['fly', 3, 12, 15, 1, 45],
        ['dbRow', 3, 10, 15, 2, 60],
        ['bbRdl', 3, 10, 12, 2, 75],
        ['facePull', 3, 12, 20, 1, 45],
      ]),
    ],
  },
  {
    name: 'Machine Gym Starter (3 days)',
    description: 'Machines and cables only. Easy to learn and easy on the joints.',
    phase: 'Beginner',
    workouts: [
      day('Day 1', 1, [
        ['legPress', 3, 10, 12, 3, 90],
        ['machineChest', 3, 10, 12, 3, 90],
        ['csRow', 3, 10, 12, 3, 90],
        ['legCurl', 2, 10, 15, 2, 60],
        ['pushdown', 2, 10, 15, 2, 60],
      ]),
      day('Day 2', 3, [
        ['hackSquat', 3, 10, 12, 3, 90],
        ['neutralPulldown', 3, 10, 12, 3, 90],
        ['fly', 3, 10, 15, 2, 60],
        ['cableLateral', 3, 12, 15, 2, 60],
        ['cableCrunch', 2, 10, 15, 2, 60],
      ]),
      day('Day 3', 5, [
        ['legPress', 3, 10, 12, 3, 90],
        ['machineChest', 3, 10, 12, 3, 90],
        ['cableRow', 3, 10, 12, 3, 90],
        ['legExt', 2, 12, 15, 2, 60],
        ['facePull', 2, 12, 15, 2, 60],
      ]),
    ],
  },
  {
    name: 'Arms and Shoulders Specialization (2 days)',
    description: 'Add-on block for lagging arms and delts. Run next to a normal 3 or 4 day plan.',
    phase: 'Specialization',
    workouts: [
      day('Arms A', 2, [
        ['cgBench', 3, 6, 10, 2, 120],
        ['ezCurl', 4, 8, 12, 1, 75],
        ['ohTri', 4, 10, 12, 1, 60],
        ['inclineCurl', 3, 10, 12, 1, 60],
        ['dbCurl', 2, 12, 15, 0, 45],
      ]),
      day('Shoulders + Arms B', 6, [
        ['dbPress', 3, 8, 10, 2, 90],
        ['lateral', 5, 12, 20, 1, 45],
        ['rearFly', 4, 12, 15, 1, 45],
        ['skull', 3, 8, 12, 1, 60],
        ['hammer', 3, 10, 12, 1, 60],
      ]),
    ],
  },
];
