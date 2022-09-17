/*
1. Data Cleansing Steps

In a single query, perform the following operations and generate a new table in the data_mart schema named clean_weekly_sales:
1. Convert the week_date to a DATE format

2. Add a week_number as the second column for each week_date value, for example any value from the 1st of January to 7th of January will be 1, 8th to 14th will be 2 etc

3. Add a month_number with the calendar month for each week_date value as the 3rd column

4. Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values

5. Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value

segment	age_band
1	Young Adults
2	Middle Aged
3 or 4	Retirees

6. Add a new demographic column using the following mapping for the first letter in the segment values:
segment	demographic
C	Couples
F	Families

7. Ensure all null string values with an "unknown" string value in the original segment column as well as the new age_band and demographic columns

8. Generate a new avg_transaction column as the sales value divided by transactions rounded to 2 decimal places for each record
*/

-- 1
CREATE TABLE cleaned_weekly_sales AS 
SELECT *,
TO_CHAR(week_date, 'WW') AS week_number,
EXTRACT('month' FROM week_date) AS month_number,
EXTRACT('year'FROM week_date) AS calendar_year,
CASE 
	WHEN RIGHT(segment,1)='1' THEN 'Young Adults'
	WHEN RIGHT(segment,1)='2' THEN 'Middle Aged'
	WHEN RIGHT(segment,1) IN ('3','4') THEN 'Retirees'
	ELSE segment END AS age_band,
CASE 
	WHEN LEFT(segment,1)='C' THEN 'Couples'
	WHEN LEFT(segment,1)='F' THEN 'Families'
	ELSE segment END AS demographic,
ROUND(sales/transactions::NUMERIC,2) AS avg_transaction
FROM (
	SELECT CONCAT('20'||SPLIT_PART(week_date,'/',3),
			'-',SPLIT_PART(week_date,'/',2),
			'-',SPLIT_PART(week_date,'/',1)
			)::DATE AS week_date,
	region,
	platform,
	CASE WHEN segment = 'null' OR segment IS NULL THEN 'unknown'
	ELSE segment END AS segment,
	customer_type,
	transactions,
	sales
	FROM datamart_weekly_sales 
) AS clean_weekdate;

/*
2. Data Exploration

a. What day of the week is used for each week_date value?
b. What range of week numbers are missing from the dataset?
c. How many total transactions were there for each year in the dataset?
d. What is the total sales for each region for each month?
e. What is the total count of transactions for each platform
f. What is the percentage of sales for Retail vs Shopify for each month?
g. What is the percentage of sales by demographic for each year in the dataset?
h. Which age_band and demographic values contribute the most to Retail sales?
i. Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?
*/

-- 2.a
SELECT TO_CHAR(week_date, 'day') AS day_of_week
FROM cleaned_weekly_sales 
LIMIT 1;

-- 2.b
WITH date_range AS (
	SELECT MIN(week_date) AS first_date,
	MAX(week_date) AS last_date
	FROM cleaned_weekly_sales
),

week_date_series AS (
	SELECT GENERATE_SERIES(first_date, last_date, '1 week') AS week_date
	FROM date_range
)
SELECT * 
FROM week_date_series
WHERE week_date NOT IN (SELECT DISTINCT week_date FROM cleaned_weekly_sales)
ORDER BY week_date;

-- 2.c
SELECT EXTRACT (YEAR FROM week_date) AS year, SUM(transactions) AS total_transactions 
FROM cleaned_weekly_sales cws 
GROUP BY year ORDER BY year;

-- 2.d
SELECT region, 
DATE_TRUNC('month', week_date) AS month,
SUM(sales) AS total_sales
FROM cleaned_weekly_sales
GROUP BY 1,2 ORDER BY 1,2;

-- 2.e
SELECT platform, 
SUM(transactions) AS total_transactions
FROM cleaned_weekly_sales
GROUP BY 1;

-- 2.f
SELECT *,
ROUND(shopify_sales/total_sales::NUMERIC,2) AS shopify_percent,
ROUND(retail_sales/total_sales::NUMERIC,2) AS retail_percent
FROM (
	SELECT 
	DATE_TRUNC('month', week_date) AS month,
	SUM(CASE WHEN platform = 'Shopify' THEN sales END) AS shopify_sales,
	SUM(CASE WHEN platform = 'Retail' THEN sales END) AS retail_sales,
	SUM(sales) AS total_sales
	FROM cleaned_weekly_sales
	GROUP BY 1 ORDER BY 1
) AS sales_split
;

-- 2.g
SELECT *,
ROUND(couples_sales/total_sales::NUMERIC,2) AS couples_percent,
ROUND(family_sales/total_sales::NUMERIC,2) AS family_percent,
ROUND(unknown_sales/total_sales::NUMERIC,2) AS unknown_percent
FROM (
	SELECT 
	EXTRACT(YEAR FROM week_date) AS year,
	SUM(CASE WHEN demographic = 'Couples' THEN sales END) AS couples_sales,
	SUM(CASE WHEN demographic = 'Families' THEN sales END) AS family_sales,
	SUM(CASE WHEN demographic = 'unknown' THEN sales END) AS unknown_sales,
	SUM(sales) AS total_sales
	FROM cleaned_weekly_sales
	GROUP BY 1 ORDER BY 1
) AS sales_split
;

-- 2.h
SELECT CONCAT(demographic, '-', age_band) AS demographic_age,
SUM(sales) AS total_sales,
RANK() OVER (ORDER BY SUM(sales) DESC) AS most_contribution
FROM cleaned_weekly_sales
WHERE platform = 'Retail'
GROUP BY 1 ORDER BY 2 DESC;

-- 2.i
-- We can't use the avg_transaction column as that would be averaging an averaged value
-- which is misleading
SELECT *,
shopify_sales/shopify_txn AS shopify_avg_transaction,
retail_sales/retail_txn AS retail_avg_transaction
FROM (
	SELECT EXTRACT (YEAR FROM week_date) AS year,
	SUM(CASE WHEN platform = 'Shopify' THEN sales END) AS shopify_sales,
	SUM(CASE WHEN platform = 'Shopify' THEN transactions END) AS shopify_txn,
	SUM(CASE WHEN platform = 'Retail' THEN sales END) AS retail_sales,
	SUM(CASE WHEN platform = 'Retail' THEN transactions END) AS retail_txn
	FROM cleaned_weekly_sales 
	GROUP BY year 
) AS sales_split
;

