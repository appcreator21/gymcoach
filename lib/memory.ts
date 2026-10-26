import { getLlmProvider } from '@/lib/llm';
import type { OnboardingAnswers } from '@/lib/schemas/onboarding';

// Hard cap so the memory file stays cheap to put in every prompt.
export const MEMORY_MAX_CHARS = 3000;

const LABELS = {
  goal: {
    HYPERTROPHY: 'Build muscle',
    STRENGTH: 'Get stronger',
    FAT_LOSS: 'Lose fat',
    RECOMP: 'Lose fat and build muscle',
    GENERAL_FITNESS: 'General fitness',
  },
  experience: {
    NEW: 'new to lifting',
    SOME: 'some experience (under 1 year)',
    EXPERIENCED: 'experienced (1-3 years)',
    ADVANCED: 'advanced (3+ years)',
  },
  location: {
    COMMERCIAL_GYM: 'commercial gym',
    HOME_GYM: 'home gym',
    MINIMAL: 'minimal equipment',
    BODYWEIGHT: 'bodyweight only',
  },
  sleep: {
    UNDER_5: 'under 5 hours',
    FIVE_TO_6: '5-6 hours',
    SEVEN_TO_8: '7-8 hours',
    OVER_8: 'over 8 hours',
  },
  lifestyle: {
    DESK: 'desk job',
    MIXED: 'mixed day',
    ON_FEET: 'on their feet most of the day',
    PHYSICAL: 'physical job',
  },
  style: {
    PUSH_ME: 'wants to be pushed hard',
    SUPPORTIVE: 'prefers a supportive tone',
    DATA_DRIVEN: 'wants numbers and reasoning',
    RELAXED: 'prefers a relaxed approach',
  },
} as const;

/** Seeds the memory file from the intake answers (deterministic, no LLM). */
export function buildInitialMemory(a: OnboardingAnswers): string {
  const lines: string[] = [`# ${a.displayName}`, '', '## Profile'];
  const facts = [
    a.age ? `${a.age} years old` : null,
    a.sex ? a.sex.toLowerCase() : null,
    a.heightCm ? `${a.heightCm} cm` : null,
    a.bodyweightKg ? `${a.bodyweightKg} kg` : null,
  ].filter(Boolean);
  if (facts.length) lines.push(`- ${facts.join(', ')}`);
  lines.push(`- Experience: ${LABELS.experience[a.experience]}`);
  if (a.lifestyle) lines.push(`- Day to day: ${LABELS.lifestyle[a.lifestyle]}`);
  if (a.sleepHours) lines.push(`- Sleep: ${LABELS.sleep[a.sleepHours]}`);

  lines.push('', '## Goals', `- Main goal: ${LABELS.goal[a.goal]}`);
  if (a.motivation) lines.push(`- Why now: ${a.motivation}`);
  if (a.focusAreas.length) lines.push(`- Wants extra focus on: ${a.focusAreas.join(', ')}`);

  lines.push(
    '',
    '## Training setup',
    `- ${a.daysPerWeek} days per week, about ${a.sessionMinutes} minutes a session`,
    `- Trains at: ${LABELS.location[a.location]}`,
  );

  lines.push('', '## Limits and dislikes');
  lines.push(`- Injuries or limits: ${a.injuries || 'none reported'}`);
  if (a.dislikes) lines.push(`- Dislikes: ${a.dislikes}`);

  lines.push('', '## How to coach them', `- ${LABELS.style[a.coachingStyle]}`, '', '## Log', '');
  return lines.join('\n').slice(0, MEMORY_MAX_CHARS);
}

const UPDATE_SYSTEM = `You maintain the private memory file a personal trainer keeps about one client.
You receive the current memory file and the latest chat exchange. Return the full updated memory file in markdown, keeping the same section headings.
Rules:
- Only record durable facts the client stated or clearly implied: goals, injuries, schedule changes, preferences, motivation, wins, equipment, lifestyle.
- Never record small talk, one-off questions, or anything you are guessing.
- Update or remove facts that are now outdated. Keep it concise: under ${MEMORY_MAX_CHARS} characters.
- Append at most one short dated line to "## Log" for a meaningful event (a new PR, an injury, a plan change).
- If nothing durable changed, return the file exactly as it was.
- Output only the memory file, no commentary.`;

/**
 * Rewrites the memory file after a chat turn. Returns the new memory, or null
 * when nothing should change (demo provider, empty reply, runaway output).
 */
export async function reviseMemory(
  current: string,
  userMessage: string,
  assistantReply: string,
  today: string,
): Promise<string | null> {
  const provider = getLlmProvider();
  if (provider.id === 'demo' || !provider.isConfigured()) return null;

  const { text } = await provider.complete({
    system: UPDATE_SYSTEM,
    maxTokens: 1500,
    temperature: 0.2,
    messages: [
      {
        role: 'user',
        content: `Today: ${today}\n\n<memory>\n${current}\n</memory>\n\n<client_message>\n${userMessage}\n</client_message>\n\n<coach_reply>\n${assistantReply}\n</coach_reply>`,
      },
    ],
  });
  const next = text.trim();
  if (!next.startsWith('#') || next.length > MEMORY_MAX_CHARS || next === current.trim()) {
    return null;
  }
  return next;
}
