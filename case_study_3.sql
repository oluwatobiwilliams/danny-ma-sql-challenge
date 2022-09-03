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
WITH churned_customers AS (
  SELECT '1'::VARCHAR AS customer_state, 
  COUNT(DISTINCT customer_id) AS churned_count
  FROM foodie_fi.subscriptions
  WHERE plan_id = 4
),
total_customers AS (
  SELECT '1'::VARCHAR AS customer_state,
  COUNT(DISTINCT customer_id) AS total_count
  FROM foodie_fi.subscriptions
)
SELECT churned_count, 
total_count,
churned_count/total_count::FLOAT*100 AS percentage_churn
FROM churned_customers
JOIN total_customers USING (customer_state);

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

