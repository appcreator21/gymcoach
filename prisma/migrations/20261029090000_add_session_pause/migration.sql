-- Workout pause/resume: additive columns with safe defaults.
-- Rollback: ALTER TABLE "Session" DROP COLUMN "pausedAt", DROP COLUMN "pausedSec";

-- AlterTable
ALTER TABLE "Session" ADD COLUMN "pausedAt" TIMESTAMP(3),
ADD COLUMN "pausedSec" INTEGER NOT NULL DEFAULT 0;
