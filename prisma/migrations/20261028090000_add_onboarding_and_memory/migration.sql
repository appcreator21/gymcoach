-- AlterTable
ALTER TABLE "User" ADD COLUMN     "onboarding" JSONB,
ADD COLUMN     "onboardedAt" TIMESTAMP(3),
ADD COLUMN     "memory" TEXT,
ADD COLUMN     "memoryUpdatedAt" TIMESTAMP(3);
