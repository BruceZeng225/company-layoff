-- 1. Remove duplicate
-- 2. Standardized data format
-- 3. Checking null and blank values
-- 4. Remove blank rows

-- locate duplicate data using row_num
WITH dupe_cte AS(
SELECT *,
	ROW_NUMBER() OVER(
	PARTITION BY company, location, industry, total_laid_off, percentage_laid_off,
    date, stage, country, funds_raised_millions) AS row_num
FROM layoffs)

-- select all duplicate data
SELECT *
FROM dupe_cte
WHERE row_num > 1;

-- check if the data is actually duplicate
SELECT *
FROM layoffs
WHERE company = 'Yahoo';

/*create staging table to avoid direct edit raw data
CREATE TABLE layoffs_staging AS
	SELECT *, 
		ROW_NUMBER() OVER(
		PARTITION BY company, location, industry, total_laid_off, percentage_laid_off,
		date, stage, country, funds_raised_millions) AS row_num
    FROM layoffs;*/

-- update data without primary key
SET SQL_SAFE_UPDATES = 0;
-- set safety mode back after update
SET SQL_SAFE_UPDATES = 1;

-- delete all duplicate data
DELETE
FROM layoffs_staging
WHERE row_num > 1;

-- trim the space in company name
UPDATE layoffs_staging
SET company = TRIM(company);

-- update all different name of the same category to the same name
UPDATE layoffs_staging
SET industry = 'Crypto'
WHERE industry LIKE 'Crypto%';

-- trim dots in country name
UPDATE layoffs_staging
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

-- format date
UPDATE layoffs_staging
SET date = str_to_date(date, '%m/%d/%Y');

-- change data type to date
ALTER TABLE layoffs_staging
MODIFY COLUMN date DATE;

-- check for blank values in industry whether there are information to fill in
SELECT l1.company, l1.industry, l2.company, l2.industry
FROM layoffs_staging as l1
INNER JOIN layoffs_staging as l2
	ON l1.company = l2.company AND l1.location = l2.location
WHERE l1.industry IS NULL OR l1.industry = ''
	AND l2.industry IS NOT NULL;

-- update all blank values to null
UPDATE layoffs_staging
SET industry = null
WHERE industry = '';

-- fill in all null values using existing values
UPDATE layoffs_staging as l1
INNER JOIN layoffs_staging as l2
	ON l1.company = l2.company
SET l1.industry = l2.industry
WHERE l1.industry IS NULL
	AND l2.industry IS NOT NULL;

-- delete all unpopulated data
DELETE FROM layoffs_staging
WHERE total_laid_off IS NULL 
	AND percentage_laid_off IS NULL;

-- drop the extra column
ALTER TABLE layoffs_staging
DROP COLUMN row_num;

-- final data
SELECT *
FROM layoffs_staging;
