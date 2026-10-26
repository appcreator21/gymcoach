-- User access level: additive only. Existing rows default to USER.
-- Rollback: ALTER TABLE "User" DROP COLUMN "role"; DROP TYPE "UserRole";

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('USER', 'ADMIN');

-- AlterTable
ALTER TABLE "User" ADD COLUMN "role" "UserRole" NOT NULL DEFAULT 'USER';
