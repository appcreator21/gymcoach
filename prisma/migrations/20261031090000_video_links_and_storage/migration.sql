-- Videos can link to a workout name and remember their storage keys.
-- Additive, nullable columns only.
-- Rollback: ALTER TABLE "VideoClip" DROP COLUMN "workoutName", DROP COLUMN "storageKey", DROP COLUMN "thumbnailKey";

-- AlterTable
ALTER TABLE "VideoClip" ADD COLUMN "workoutName" TEXT,
ADD COLUMN "storageKey" TEXT,
ADD COLUMN "thumbnailKey" TEXT;

-- CreateIndex
CREATE INDEX "VideoClip_workoutName_idx" ON "VideoClip"("workoutName");
