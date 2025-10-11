-- CreateTable
CREATE TABLE "DailyStats" (
    "userId" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "kcal" INTEGER NOT NULL DEFAULT 0,
    "protein" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "carb" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "fat" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "sugars" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "fiber" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "salt" DECIMAL(10,2) NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DailyStats_pkey" PRIMARY KEY ("userId","date")
);

-- CreateTable
CREATE TABLE "WeightLog" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "day" DATE NOT NULL,
    "weightKg" DECIMAL(5,2) NOT NULL,
    "source" TEXT,
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "WeightLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "DailyStats_userId_date_idx" ON "DailyStats"("userId", "date");

-- CreateIndex
CREATE INDEX "WeightLog_userId_day_idx" ON "WeightLog"("userId", "day");

-- CreateIndex
CREATE UNIQUE INDEX "WeightLog_userId_day_key" ON "WeightLog"("userId", "day");

-- AddForeignKey
ALTER TABLE "WeightLog" ADD CONSTRAINT "WeightLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
