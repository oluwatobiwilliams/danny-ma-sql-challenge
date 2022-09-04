/*
A. Customer Journey
Based off the 8 sample customers provided in the sample from the subscriptions table, write a brief description about each customer’s onboarding journey.

Try to keep it as short as possible - you may also want to run some sort of join to make your explanations a bit easier!
*/

-- A answers
/*
customer 1: downgraded to basic plan after the 7-day trial
customer 2: upgraded to pro annual after the trial
customer 11: churned after the trial period
customer 13: initially started off on the basic, 4 months after switched to pro monthly
customer 15: after the trial, started off on the pro monthly, about a monthly after, churned
customer 16: after the trial, switched to the basic monthly, and after 4 months+ upgraded to pro annual
customer 18: after the trial, remained on the pro monthly
customer 19: after the trial, remained on the pro monthly for two months before switching to pro annual
*/

/*
B. Data Analysis Questions

1. How many customers has Foodie-Fi ever had?
2. What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
3. What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
4. What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
5. How many customers have churned straight after their initial free trial - what percentage is this rounded to the nearest whole number?
6. What is the number and percentage of customer plans after their initial free trial?
7. What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
8. How many customers have upgraded to an annual plan in 2020?
9. How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
10. Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
11. How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
*/

-- B.1
SELECT COUNT(DISTINCT customer_id) AS no_of_customers_ever
FROM foodie_fi.subscriptions;

-- B.2
SELECT DATE_TRUNC('month',start_date) AS month_start, 
COUNT(*) AS no_of_trial_plan
FROM foodie_fi.subscriptions
WHERE plan_id = 0
GROUP BY month_start;

-- B.3
SELECT plan_name, COUNT(*) AS no_of_events
FROM foodie_fi.subscriptions
LEFT JOIN foodie_fi.plans USING (plan_id)
WHERE start_date > '2020-12-31'
GROUP BY plan_name
ORDER BY no_of_events DESC;

-- B.4
SELECT churned_customers, 
total_customers,
ROUND(churned_customers/total_customers::NUMERIC*100,1) AS percent_churned
FROM (
SELECT 
  COUNT (CASE WHEN plan_id = 4 THEN 1 END) AS churned_customers,
  COUNT (CASE WHEN plan_id = 0 THEN 1 END) AS total_customers
  FROM foodie_fi.subscriptions
) AS tmp;

-- B.5
WITH subscribers AS (
  SELECT customer_id, 
  STRING_AGG(plan_id::VARCHAR, ', ') AS plan_id 
  FROM (
    SELECT *, 
    ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS row_num
    FROM foodie_fi.subscriptions
  ) AS tmp
  WHERE row_num IN (1,2) AND plan_id IN (0, 4)
  GROUP BY customer_id
  ORDER BY customer_id
)
SELECT churn_after_trial, total_customers, 
ROUND(churn_after_trial/total_customers::FLOAT*100) AS percent_churn_after_trial
FROM (
  SELECT COUNT (CASE WHEN plan_id <> '0' THEN 1 END) AS churn_after_trial,
  COUNT (*) AS total_customers
  FROM subscribers
) tmp;

-- B.5 v2 using the LEAD function
SELECT churned_customers,
total_customers,
ROUND(churned_customers/total_customers::FLOAT*100) AS percent_churned_after_trial
FROM (
  SELECT 
  COUNT(CASE WHEN plan_id = 0 AND lead_plan = 4 THEN 1 END) AS churned_customers,
  COUNT(DISTINCT customer_id) AS total_customers
  FROM (
    SELECT *,
    LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS lead_plan
    FROM foodie_fi.subscriptions
    ORDER BY customer_id
  ) AS tmp
) AS tmp;

-- B.6
SELECT lead_plan, no_of_customers,
ROUND(no_of_customers::NUMERIC/SUM(no_of_customers) OVER ()*100,1) AS percent_customer_plan
FROM (
  SELECT lead_plan, 
  COUNT(*) AS no_of_customers
  FROM (
      SELECT *,
      LEAD(plan_id) OVER (PARTITION BY customer_id ORDER BY start_date) AS lead_plan
      FROM foodie_fi.subscriptions	
    ) AS tmp
  WHERE plan_id = 0
  GROUP BY lead_plan
  ORDER BY lead_plan ASC
  ) tmp;

  -- B.7
WITH subscriptions AS (
SELECT *, 
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY start_date) AS row_num
  FROM foodie_fi.subscriptions
  WHERE start_date <= '2020-12-31'
),
max_row_per_customer AS (
	SELECT customer_id, MAX(row_num) AS max_row
  	FROM subscriptions
  	GROUP BY customer_id
)
SELECT plan_id, 
no_of_customers,
ROUND(no_of_customers::NUMERIC/SUM(no_of_customers) OVER ()*100,1) AS percent_breakdown
FROM (
  SELECT plan_id, 
  COUNT(*) AS no_of_customers
  FROM (
    SELECT * 
    FROM subscriptions s
    JOIN max_row_per_customer m
    ON s.customer_id = m.customer_id AND s.row_num = m.max_row
  ) tmp
  GROUP BY plan_id
) tmp;
