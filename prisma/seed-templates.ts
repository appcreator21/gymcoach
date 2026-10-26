// Seeds the starter program templates into an admin's account.
//
//   DATABASE_URL=... npx tsx prisma/seed-templates.ts <admin-email>
//
// Idempotent: a template is only created when the database has none with the
// same name, so templates an admin has edited or deleted are left alone
// (a deleted one comes back on the next run; delete it from the seed list to
// stop that). Validates every template with the same schema the API uses.
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from './generated/client';
import { generatedProgramSchema } from '../lib/schemas/program-generation';
import { PROGRAM_TEMPLATES } from './templates';

async function main() {
  const email = process.argv[2];
  if (!email) throw new Error('Usage: tsx prisma/seed-templates.ts <admin-email>');

  const db = new PrismaClient({
    adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL }),
  });
  try {
    const user = await db.user.findUnique({ where: { email }, select: { id: true } });
    if (!user) throw new Error(`No user with email ${email}`);

    let created = 0;
    for (const template of PROGRAM_TEMPLATES) {
      const program = generatedProgramSchema.parse(template);
      const exists = await db.programTemplate.findFirst({
        where: { name: program.name },
        select: { id: true },
      });
      if (exists) continue;
      await db.programTemplate.create({
        data: {
          name: program.name,
          description: program.description ?? null,
          phase: program.phase,
          data: program,
          createdById: user.id,
        },
      });
      created += 1;
    }
    console.log(
      `Seeded ${created} new template(s); ${PROGRAM_TEMPLATES.length - created} already existed.`,
    );
  } finally {
    await db.$disconnect();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
