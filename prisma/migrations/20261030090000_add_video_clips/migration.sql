-- Coach videos: one new table, no change to existing ones.
-- Rollback: DROP TABLE "VideoClip";

-- CreateTable
CREATE TABLE "VideoClip" (
    "id" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "videoUrl" TEXT NOT NULL,
    "thumbnailUrl" TEXT,
    "category" TEXT NOT NULL DEFAULT 'Workouts',
    "exerciseName" TEXT,
    "durationSec" INTEGER,
    "featured" BOOLEAN NOT NULL DEFAULT false,
    "createdById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "VideoClip_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "VideoClip_category_createdAt_idx" ON "VideoClip"("category", "createdAt");

-- CreateIndex
CREATE INDEX "VideoClip_exerciseName_idx" ON "VideoClip"("exerciseName");
