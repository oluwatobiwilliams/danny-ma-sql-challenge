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
-- which is misleading in this case
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

/*
3. Before & After Analysis
This technique is usually used when we inspect an important event and want to inspect the impact before and after a certain point in time.

Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart sustainable packaging changes came into effect.

We would include all week_date values for 2020-06-15 as the start of the period after the change and the previous week_date values would be before

Using this analysis approach - answer the following questions:

1. What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?
2. What about the entire 12 weeks before and after?
3. How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
*/

-- 3.1 version 1
SELECT before_effect,
after_effect,
after_effect - before_effect AS change,
ROUND(((after_effect/before_effect::NUMERIC) - 1)*100,2) AS percent_change
FROM 
(
	SELECT SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN 1 AND 4 THEN sales END) AS after_effect,
	SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN -3 AND 0 THEN sales END) AS before_effect
	FROM
	(
		SELECT week_date,
		ROUND((week_date - '2020-06-15'::DATE)/7.0)+1 AS delta_weeks,
		sales 
		FROM cleaned_weekly_sales
	) add_delta_weeks
) AS add_before_after
;

-- 3.1 version 2
SELECT before_effect,
after_effect,
after_effect - before_effect AS change,
ROUND(((after_effect/before_effect::NUMERIC) - 1)*100,2) AS percent_change
FROM (
	SELECT SUM(CASE WHEN week_date BETWEEN '2020-05-18' AND '2020-06-08' THEN sales END) AS before_effect,
	SUM(CASE WHEN week_date BETWEEN '2020-06-15' AND '2020-07-06' THEN sales END) AS after_effect
	FROM (
		SELECT week_date,
		sales 
		FROM cleaned_weekly_sales
		WHERE week_date BETWEEN '2020-06-15'::DATE - INTERVAL '4 week' 
		AND '2020-06-15'::DATE + INTERVAL '3 week'
		ORDER BY week_date 
	) AS add_delta_weeks
) AS generate_before_after
;

-- 3.2 
SELECT before_effect,
after_effect,
after_effect - before_effect AS change,
ROUND(((after_effect/before_effect::NUMERIC) - 1)*100,2) AS percent_change
FROM 
(
	SELECT SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN 1 AND 12 THEN sales END) AS after_effect,
	SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN -11 AND 0 THEN sales END) AS before_effect
	FROM
	(
		SELECT week_date,
		ROUND((week_date - '2020-06-15'::DATE)/7.0)+1 AS delta_weeks,
		sales 
		FROM cleaned_weekly_sales
	) add_delta_weeks
) AS add_before_after
;

-- 3.3 For 4 weeks before and after
SELECT before_effect,
after_effect,
after_effect - before_effect AS change,
ROUND(((after_effect/before_effect::NUMERIC) - 1)*100,2) AS percent_change,
'2018' AS year
FROM 
(
	SELECT SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN 1 AND 4 THEN sales END) AS after_effect,
	SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN -3 AND 0 THEN sales END) AS before_effect
	FROM
	(
		SELECT week_date,
		ROUND((week_date - '2018-06-15'::DATE)/7.0)+1 AS delta_weeks,
		sales 
		FROM cleaned_weekly_sales
	) add_delta_weeks
) AS add_before_after

UNION ALL 

SELECT before_effect,
after_effect,
after_effect - before_effect AS change,
ROUND(((after_effect/before_effect::NUMERIC) - 1)*100,2) AS percent_change,
'2019' AS year
FROM 
(
	SELECT SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN 1 AND 4 THEN sales END) AS after_effect,
	SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN -3 AND 0 THEN sales END) AS before_effect
	FROM
	(
		SELECT week_date,
		ROUND((week_date - '2019-06-15'::DATE)/7.0)+1 AS delta_weeks,
		sales 
		FROM cleaned_weekly_sales
	) add_delta_weeks
) AS add_before_after

UNION ALL

SELECT before_effect,
after_effect,
after_effect - before_effect AS change,
ROUND(((after_effect/before_effect::NUMERIC) - 1)*100,2) AS percent_change,
'2020' AS year
FROM 
(
	SELECT SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN 1 AND 4 THEN sales END) AS after_effect,
	SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN -3 AND 0 THEN sales END) AS before_effect
	FROM
	(
		SELECT week_date,
		ROUND((week_date - '2020-06-15'::DATE)/7.0)+1 AS delta_weeks,
		sales 
		FROM cleaned_weekly_sales
	) add_delta_weeks
) AS add_before_after
;

/*
4. Bonus Question
Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?

region
platform
age_band
demographic
customer_type
Do you have any further recommendations for Danny’s team at Data Mart or any interesting insights based off this analysis?
*/

SELECT metric, AVG(percent_change) AS  avg_percent_change
FROM (
	SELECT 'region' AS metric,
	LOWER(region) AS value,
	before_effect,
	after_effect,
	after_effect - before_effect AS change,
	ROUND(((after_effect/before_effect::NUMERIC) - 1)*100,2) AS percent_change
	FROM 
	(
		SELECT region,
		SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN 1 AND 12 THEN sales END) AS after_effect,
		SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN -11 AND 0 THEN sales END) AS before_effect
		FROM
		(
			SELECT region,
			week_date,
			ROUND((week_date - '2020-06-15'::DATE)/7.0)+1 AS delta_weeks,
			sales 
			FROM cleaned_weekly_sales
		) add_delta_weeks
		GROUP BY region
	) AS add_before_after
	
	UNION ALL 
	
	SELECT 'platform' AS metric,
	LOWER(platform) AS value,
	before_effect,
	after_effect,
	after_effect - before_effect AS change,
	ROUND(((after_effect/before_effect::NUMERIC) - 1)*100,2) AS percent_change
	FROM 
	(
		SELECT platform,
		SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN 1 AND 12 THEN sales END) AS after_effect,
		SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN -11 AND 0 THEN sales END) AS before_effect
		FROM
		(
			SELECT platform,
			week_date,
			ROUND((week_date - '2020-06-15'::DATE)/7.0)+1 AS delta_weeks,
			sales 
			FROM cleaned_weekly_sales
		) add_delta_weeks
		GROUP BY platform
	) AS add_before_after
	
	UNION ALL 
	
	SELECT 'age_band' AS metric,
	LOWER(age_band) AS value,
	before_effect,
	after_effect,
	after_effect - before_effect AS change,
	ROUND(((after_effect/before_effect::NUMERIC) - 1)*100,2) AS percent_change
	FROM 
	(
		SELECT age_band,
		SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN 1 AND 12 THEN sales END) AS after_effect,
		SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN -11 AND 0 THEN sales END) AS before_effect
		FROM
		(
			SELECT age_band,
			week_date,
			ROUND((week_date - '2020-06-15'::DATE)/7.0)+1 AS delta_weeks,
			sales 
			FROM cleaned_weekly_sales
		) add_delta_weeks
		GROUP BY age_band
	) AS add_before_after
	
	UNION ALL 
	
	SELECT 'demographic' AS metric,
	LOWER(demographic) AS value,
	before_effect,
	after_effect,
	after_effect - before_effect AS change,
	ROUND(((after_effect/before_effect::NUMERIC) - 1)*100,2) AS percent_change
	FROM 
	(
		SELECT demographic,
		SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN 1 AND 12 THEN sales END) AS after_effect,
		SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN -11 AND 0 THEN sales END) AS before_effect
		FROM
		(
			SELECT demographic,
			week_date,
			ROUND((week_date - '2020-06-15'::DATE)/7.0)+1 AS delta_weeks,
			sales 
			FROM cleaned_weekly_sales
		) add_delta_weeks
		GROUP BY demographic
	) AS add_before_after
	
	UNION ALL 
	
	SELECT 'customer_type' AS metric,
	LOWER(customer_type) AS value,
	before_effect,
	after_effect,
	after_effect - before_effect AS change,
	ROUND(((after_effect/before_effect::NUMERIC) - 1)*100,2) AS percent_change
	FROM 
	(
		SELECT customer_type,
		SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN 1 AND 12 THEN sales END) AS after_effect,
		SUM(CASE WHEN delta_weeks::NUMERIC BETWEEN -11 AND 0 THEN sales END) AS before_effect
		FROM
		(
			SELECT customer_type,
			week_date,
			ROUND((week_date - '2020-06-15'::DATE)/7.0)+1 AS delta_weeks,
			sales 
			FROM cleaned_weekly_sales
		) add_delta_weeks
		GROUP BY customer_type
	) AS add_before_after
) AS tmp
GROUP BY metric
ORDER BY avg_percent_change
;
-- Having observed the change before and after 12 weeks, it was observed that demographic and age_band
-- had the highest negative impact on sales performance. Further breakdown shows that the unknown segments
-- in demographic and age_band had the highest negative impact on sales.


