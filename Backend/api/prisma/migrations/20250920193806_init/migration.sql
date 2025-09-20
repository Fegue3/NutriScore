-- CreateEnum
CREATE TYPE "public"."NutriGrade" AS ENUM ('A', 'B', 'C', 'D', 'E');

-- CreateEnum
CREATE TYPE "public"."MealType" AS ENUM ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK');

-- CreateEnum
CREATE TYPE "public"."Unit" AS ENUM ('GRAM', 'ML', 'PIECE');

-- CreateTable
CREATE TABLE "public"."User" (
    "id" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "name" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."UserPreferences" (
    "userId" TEXT NOT NULL,
    "lowSalt" BOOLEAN NOT NULL DEFAULT false,
    "lowSugar" BOOLEAN NOT NULL DEFAULT false,
    "vegetarian" BOOLEAN NOT NULL DEFAULT false,
    "vegan" BOOLEAN NOT NULL DEFAULT false,
    "allergens" TEXT,
    "dailyCalories" INTEGER,
    "carbPercent" INTEGER,
    "proteinPercent" INTEGER,
    "fatPercent" INTEGER,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserPreferences_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "public"."UserGoals" (
    "userId" TEXT NOT NULL,
    "currentWeightKg" DECIMAL(5,2),
    "targetWeightKg" DECIMAL(5,2),
    "targetDate" TIMESTAMP(3),
    "activityLevel" TEXT,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "UserGoals_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "public"."Product" (
    "id" TEXT NOT NULL,
    "barcode" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "brand" TEXT,
    "quantity" TEXT,
    "servingSize" TEXT,
    "imageUrl" TEXT,
    "countries" TEXT,
    "nutriScore" "public"."NutriGrade",
    "nutriScoreScore" INTEGER,
    "novaGroup" INTEGER,
    "ecoScore" TEXT,
    "categories" TEXT,
    "labels" TEXT,
    "allergens" TEXT,
    "ingredientsText" TEXT,
    "energyKcal_100g" INTEGER,
    "proteins_100g" DECIMAL(6,2),
    "carbs_100g" DECIMAL(6,2),
    "sugars_100g" DECIMAL(6,2),
    "fat_100g" DECIMAL(6,2),
    "satFat_100g" DECIMAL(6,2),
    "fiber_100g" DECIMAL(6,2),
    "salt_100g" DECIMAL(6,2),
    "sodium_100g" DECIMAL(6,2),
    "energyKcal_serv" INTEGER,
    "proteins_serv" DECIMAL(6,2),
    "carbs_serv" DECIMAL(6,2),
    "sugars_serv" DECIMAL(6,2),
    "fat_serv" DECIMAL(6,2),
    "satFat_serv" DECIMAL(6,2),
    "fiber_serv" DECIMAL(6,2),
    "salt_serv" DECIMAL(6,2),
    "sodium_serv" DECIMAL(6,2),
    "lastFetchedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "off_raw" JSONB,

    CONSTRAINT "Product_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."ProductHistory" (
    "id" BIGSERIAL NOT NULL,
    "userId" TEXT NOT NULL,
    "barcode" TEXT,
    "scannedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "nutriScore" "public"."NutriGrade",
    "calories" INTEGER,
    "sugars" DECIMAL(6,2),
    "fat" DECIMAL(6,2),
    "salt" DECIMAL(6,2),

    CONSTRAINT "ProductHistory_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."FavoriteProduct" (
    "userId" TEXT NOT NULL,
    "barcode" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "FavoriteProduct_pkey" PRIMARY KEY ("userId","barcode")
);

-- CreateTable
CREATE TABLE "public"."CustomFood" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "brand" TEXT,
    "defaultUnit" "public"."Unit" NOT NULL DEFAULT 'GRAM',
    "gramsPerUnit" DECIMAL(7,2),
    "energyKcal_100g" INTEGER,
    "proteins_100g" DECIMAL(6,2),
    "carbs_100g" DECIMAL(6,2),
    "sugars_100g" DECIMAL(6,2),
    "fat_100g" DECIMAL(6,2),
    "satFat_100g" DECIMAL(6,2),
    "fiber_100g" DECIMAL(6,2),
    "salt_100g" DECIMAL(6,2),
    "sodium_100g" DECIMAL(6,2),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CustomFood_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."CustomMeal" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "totalKcal" INTEGER,
    "totalProtein" DECIMAL(8,2),
    "totalCarb" DECIMAL(8,2),
    "totalFat" DECIMAL(8,2),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CustomMeal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."CustomMealItem" (
    "id" TEXT NOT NULL,
    "customMealId" TEXT NOT NULL,
    "customFoodId" TEXT,
    "productBarcode" TEXT,
    "unit" "public"."Unit" NOT NULL DEFAULT 'GRAM',
    "quantity" DECIMAL(10,2) NOT NULL,
    "gramsTotal" DECIMAL(10,2),
    "kcal" INTEGER,
    "protein" DECIMAL(8,2),
    "carb" DECIMAL(8,2),
    "fat" DECIMAL(8,2),
    "position" INTEGER,

    CONSTRAINT "CustomMealItem_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."Meal" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "date" TIMESTAMP(3) NOT NULL,
    "type" "public"."MealType" NOT NULL,
    "notes" TEXT,
    "totalKcal" INTEGER,
    "totalProtein" DECIMAL(8,2),
    "totalCarb" DECIMAL(8,2),
    "totalFat" DECIMAL(8,2),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Meal_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "public"."MealItem" (
    "id" TEXT NOT NULL,
    "mealId" TEXT NOT NULL,
    "productBarcode" TEXT,
    "customFoodId" TEXT,
    "unit" "public"."Unit" NOT NULL DEFAULT 'GRAM',
    "quantity" DECIMAL(10,2) NOT NULL,
    "gramsTotal" DECIMAL(10,2),
    "kcal" INTEGER,
    "protein" DECIMAL(8,2),
    "carb" DECIMAL(8,2),
    "fat" DECIMAL(8,2),
    "sugars" DECIMAL(8,2),
    "fiber" DECIMAL(8,2),
    "salt" DECIMAL(8,2),
    "position" INTEGER,
    "userId" TEXT,

    CONSTRAINT "MealItem_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "public"."User"("email");

-- CreateIndex
CREATE UNIQUE INDEX "Product_barcode_key" ON "public"."Product"("barcode");

-- CreateIndex
CREATE INDEX "Product_name_idx" ON "public"."Product"("name");

-- CreateIndex
CREATE INDEX "Product_brand_idx" ON "public"."Product"("brand");

-- CreateIndex
CREATE INDEX "Product_categories_idx" ON "public"."Product"("categories");

-- CreateIndex
CREATE INDEX "ProductHistory_userId_scannedAt_idx" ON "public"."ProductHistory"("userId", "scannedAt");

-- CreateIndex
CREATE INDEX "ProductHistory_barcode_idx" ON "public"."ProductHistory"("barcode");

-- CreateIndex
CREATE INDEX "Meal_userId_date_idx" ON "public"."Meal"("userId", "date");

-- CreateIndex
CREATE UNIQUE INDEX "Meal_userId_date_type_key" ON "public"."Meal"("userId", "date", "type");

-- AddForeignKey
ALTER TABLE "public"."UserPreferences" ADD CONSTRAINT "UserPreferences_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."UserGoals" ADD CONSTRAINT "UserGoals_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."ProductHistory" ADD CONSTRAINT "ProductHistory_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."ProductHistory" ADD CONSTRAINT "ProductHistory_barcode_fkey" FOREIGN KEY ("barcode") REFERENCES "public"."Product"("barcode") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."FavoriteProduct" ADD CONSTRAINT "FavoriteProduct_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."FavoriteProduct" ADD CONSTRAINT "FavoriteProduct_barcode_fkey" FOREIGN KEY ("barcode") REFERENCES "public"."Product"("barcode") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."CustomFood" ADD CONSTRAINT "CustomFood_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."CustomMeal" ADD CONSTRAINT "CustomMeal_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."CustomMealItem" ADD CONSTRAINT "CustomMealItem_customMealId_fkey" FOREIGN KEY ("customMealId") REFERENCES "public"."CustomMeal"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."CustomMealItem" ADD CONSTRAINT "CustomMealItem_customFoodId_fkey" FOREIGN KEY ("customFoodId") REFERENCES "public"."CustomFood"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."CustomMealItem" ADD CONSTRAINT "CustomMealItem_productBarcode_fkey" FOREIGN KEY ("productBarcode") REFERENCES "public"."Product"("barcode") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."Meal" ADD CONSTRAINT "Meal_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."MealItem" ADD CONSTRAINT "MealItem_mealId_fkey" FOREIGN KEY ("mealId") REFERENCES "public"."Meal"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."MealItem" ADD CONSTRAINT "MealItem_productBarcode_fkey" FOREIGN KEY ("productBarcode") REFERENCES "public"."Product"("barcode") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."MealItem" ADD CONSTRAINT "MealItem_customFoodId_fkey" FOREIGN KEY ("customFoodId") REFERENCES "public"."CustomFood"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "public"."MealItem" ADD CONSTRAINT "MealItem_userId_fkey" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
