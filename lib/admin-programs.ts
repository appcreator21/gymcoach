import { db } from '@/lib/db';
import { ApiError } from '@/lib/api';
import { buildProgramFromGenerated } from '@/lib/program-generation';
import {
  generatedProgramSchema,
  type GeneratedProgram,
} from '@/lib/schemas/program-generation';

// Makes one program the user's only active program.
export async function activateProgramFor(userId: string, programId: string): Promise<void> {
  await db.$transaction([
    db.program.updateMany({
      where: { userId, isActive: true, id: { not: programId } },
      data: { isActive: false },
    }),
    db.program.update({ where: { id: programId }, data: { isActive: true } }),
  ]);
}

// Saves a generated program into a client's account, optionally activating it.
export async function saveProgramForUser(
  userId: string,
  program: GeneratedProgram,
  activate: boolean,
): Promise<string> {
  const id = await buildProgramFromGenerated(userId, program);
  if (activate) await activateProgramFor(userId, id);
  return id;
}

// Template data is stored as JSON, so it is re-validated before every use: a
// template written by an older version of the schema must fail loudly rather
// than write a malformed program.
export function parseTemplateData(data: unknown): GeneratedProgram {
  const parsed = generatedProgramSchema.safeParse(data);
  if (!parsed.success) {
    throw new ApiError(422, 'This template is no longer valid. Recreate it.');
  }
  return parsed.data;
}
