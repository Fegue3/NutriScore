/*
  Warnings:

  - You are about to drop the column `salt` on the `ProductHistory` table. All the data in the column will be lost.
  - You are about to drop the column `sugars` on the `ProductHistory` table. All the data in the column will be lost.
  - You are about to drop the `UserPreferences` table. If the table is not empty, all the data it contains will be lost.
  - Added the required column `passwordHash` to the `User` table without a default value. This is not possible if the table is not empty.

*/
-- CreateEnum
CREATE TYPE "public"."Sex" AS ENUM ('MALE', 'FEMALE', 'OTHER');

-- DropForeignKey
ALTER TABLE "public"."UserPreferences" DROP CONSTRAINT "UserPreferences_userId_fkey";

-- AlterTable
ALTER TABLE "public"."ProductHistory" DROP COLUMN "salt",
DROP COLUMN "sugars",
ADD COLUMN     "carbs" DECIMAL(6,2),
ADD COLUMN     "proteins" DECIMAL(6,2);

-- AlterTable
ALTER TABLE "public"."User" ADD COLUMN     "onboardingCompleted" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "passwordHash" TEXT NOT NULL,
ADD COLUMN     "refreshTokenHash" TEXT;

-- AlterTable
ALTER TABLE "public"."UserGoals" ADD COLUMN     "allergens" TEXT,
ADD COLUMN     "carbPercent" INTEGER,
ADD COLUMN     "dailyCalories" INTEGER,
ADD COLUMN     "dateOfBirth" TIMESTAMP(3),
ADD COLUMN     "fatPercent" INTEGER,
ADD COLUMN     "heightCm" INTEGER,
ADD COLUMN     "lowSalt" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "lowSugar" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "proteinPercent" INTEGER,
ADD COLUMN     "sex" "public"."Sex",
ADD COLUMN     "vegan" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "vegetarian" BOOLEAN NOT NULL DEFAULT false;

-- DropTable
DROP TABLE "public"."UserPreferences";
