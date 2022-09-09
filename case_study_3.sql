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

-- B.8
SELECT COUNT (DISTINCT customer_id)
FROM foodie_fi.subscriptions
WHERE plan_id = 3 AND EXTRACT(year FROM start_date) = 2020;

-- B.9
SELECT ROUND(AVG(annual.start_date - trial.start_date),1) AS avg_days
FROM foodie_fi.subscriptions AS trial
JOIN foodie_fi.subscriptions AS annual USING (customer_id)
WHERE trial.plan_id = 0 AND annual.plan_id = 3;

-- B.10
WITH customer_upgrade AS (
SELECT trial.customer_id, 
  trial.start_date AS trial, 
  annual.start_date AS annual,
  annual.start_date - trial.start_date AS date_interval
FROM foodie_fi.subscriptions AS trial
JOIN foodie_fi.subscriptions AS annual USING (customer_id)
  WHERE trial.plan_id = 0 AND annual.plan_id = 3
)
SELECT SPLIT_PART(interval_group, ' ',2) AS interval_days, 
ROUND(AVG(date_interval),1) AS avg_days,
COUNT(*) AS no_of_customers
FROM
(
  SELECT *,
  CASE WHEN date_interval BETWEEN 0 AND 30 THEN '1 0-30'
      WHEN date_interval BETWEEN 31 AND 60 THEN '2 31-60'
      WHEN date_interval BETWEEN 61 AND 90 THEN '3 61-90'
      WHEN date_interval BETWEEN 91 AND 120 THEN '4 91-120'
      WHEN date_interval BETWEEN 121 AND 150 THEN '5 121-150'
      WHEN date_interval BETWEEN 151 AND 180 THEN '6 151-180'
      WHEN date_interval > 180 THEN '7 181+' END AS interval_group
  FROM customer_upgrade
) tmp
GROUP BY interval_group
ORDER BY interval_group;

-- B.11
WITH customer_downgrade AS (
SELECT pro.customer_id, 
  pro.start_date AS pro_date,
  pro.plan_id,
  basic.start_date AS basic_date,
  basic.plan_id
FROM foodie_fi.subscriptions AS pro
JOIN foodie_fi.subscriptions AS basic USING (customer_id)
  WHERE pro.plan_id = 2 AND basic.plan_id = 1 
  AND pro.start_date < basic.start_date
  AND EXTRACT(year FROM basic.start_date) = 2020
)
SELECT * FROM customer_downgrade;

-- B.11 version 2
WITH base_table AS (
  SELECT customer_id, STRING_AGG(plan_id::TEXT, ', ') AS customer_journey
  FROM foodie_fi.subscriptions
  WHERE EXTRACT(year FROM start_date) = 2020
  GROUP BY customer_id
)
SELECT * FROM base_table
WHERE customer_journey LIKE '%2, 1%';


/*
The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:

1. monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
2. upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
3. upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
4. once a customer churns they will no longer make payments
*/

-- C answer (in progress)

WITH subscriptions AS (
SELECT *
FROM foodie_fi.subscriptions
WHERE plan_id <> 0
),
customer_journey AS (
SELECT customer_id, ARRAY_AGG(plan_id) AS plan_journey, ARRAY_AGG(start_date) AS sub_date
FROM subscriptions
GROUP BY customer_id
ORDER BY customer_id
),
payments AS (
  
  SELECT *,
  GENERATE_SERIES(sub_date[1], COALESCE(sub_date[2],'2020-12-31'), '1 month') AS series
  FROM customer_journey 

  UNION ALL

  SELECT customer_id, plan_journey, sub_date, MIN(series) AS series
  FROM (
  SELECT *,
    GENERATE_SERIES(sub_date[2], COALESCE(sub_date[3],'2020-12-31'), '1 month') AS series
    FROM customer_journey
    ORDER BY customer_id
  ) AS tmp
  WHERE plan_journey IN (ARRAY[1,3,4], ARRAY[1,3], ARRAY[1,2,3], ARRAY[2,3])
  GROUP BY 1,2,3

  UNION ALL
  
  SELECT *,
  GENERATE_SERIES(sub_date[2], COALESCE(sub_date[3], CASE WHEN plan_journey[2]<>4 THEN '2020-12-31'::DATE END), '1 month') AS series
  FROM customer_journey
  WHERE plan_journey NOT IN (ARRAY[1,3,4], ARRAY[1,3], ARRAY[1,2,3], ARRAY[2,3])
  ORDER BY customer_id  
)

SELECT * 
FROM payments
WHERE plan_journey[1]<>4
AND EXTRACT(YEAR FROM series) = 2020
-- test cases AND customer_id IN (21,33,40,910,911,1000,996,206,219 )
--AND plan_journey @> ARRAY[4]
ORDER BY customer_id, series

--C answer alternative (in progress)

WITH customers AS (
            SELECT customer_id, 
              plan_id, 
              start_date
            FROM foodie_fi.subscriptions
            WHERE plan_id <> 0 and EXTRACT(year from start_date) <> 2021
            ORDER BY 1,2
            LIMIT 100
),

x0 as (select customer_id,ARRAY_AGG(plan_id) AS plan_journey  
		from customers
group by 1
order by 1),
plan1 as (
            select customer_id,plan_journey from x0
            where plan_journey = array[1]  or plan_journey = array[2]),
plan1or2 as (
            select customer_id,plan_journey from x0
            where  plan_journey = array[1,2]),
            
plan123 as (select customer_id,plan_journey from x0
            where plan_journey = array[1,2,3] or plan_journey = array[1,3]
            or plan_journey = array[2,3] or plan_journey = array[3]),
            
plan1234 as(select customer_id,plan_journey from x0
            where plan_journey = array[1,2,3,4] or plan_journey = array[1,4]
            or plan_journey = array[2,4] or plan_journey = array[3,4] 
             or plan_journey = array[4]  or plan_journey = array[1,2,4] 
              or plan_journey = array[1,3,4]),

p1 as (select customer_id 
       ,GENERATE_SERIES(MIN(c.start_date)::date,'2020-12-31'::date ,'1 month') as series1
       from plan1
	   left join customers c using (customer_id)
       group by 1),
        
p2 as (select customer_id, series1 
       from( select *, 
       row_number() over(partition by customer_id order by series1 ) as rankin
       from(select customer_id 
             ,GENERATE_SERIES(MIN(c.start_date)::date,
                              Max(c.start_date)::date ,
                              '1 month') as series1

             from plan1or2
             left join customers c using (customer_id)
             group by 1 )x1 )x2 
             where rankin = 1
             union 
             select customer_id, series1 from( select *, 
             row_number() over(partition by customer_id order by series1 desc ) as rankin
             from(select customer_id 
                   ,GENERATE_SERIES(MIN(c.start_date)::date,
                                    Max(c.start_date)::date ,
                                    '1 month') as series1

             from plan1or2
             left join customers c using (customer_id)
             group by 1 )x1 )x2 
             where rankin <> 1
       
       union 
      select customer_id 
             ,GENERATE_SERIES(Max(c.start_date)::date,'2020-12-31'::date ,'1 month') as series1
             from plan1or2
             left join customers c using (customer_id)
             group by 1 
             order by 1,2),
                          
p3 as (select customer_id, series1
       from( 
         
         select *, 
       row_number() over(partition by customer_id order by series1 ) as rankin
       from(select customer_id 
             ,GENERATE_SERIES(MIN(c.start_date)::date,
                              Max(c.start_date)::date ,
                              '1 month') as series1

             from plan123
             left join customers c using (customer_id)
             group by 1 )x1 )x2 
              where rankin in (1,2)
             union 
             select customer_id, series1 from( select *, 
             row_number() over(partition by customer_id order by series1 desc ) as rankin
             from(select customer_id 
                   ,GENERATE_SERIES(MIN(c.start_date)::date,
                                    Max(c.start_date)::date ,
                                    '1 month') as series1

             from plan1or2
             left join customers c using (customer_id)
             group by 1 )x1 )x2 
             where rankin <> 1
              
       
       union 
      select customer_id 
             ,Max(c.start_date) as series1
             from plan123
             left join customers c using (customer_id)
             group by 1 
             order by 1,2),
             
p4 as ( select customer_id 
       ,GENERATE_SERIES(MIN(c.start_date)::date,
                        Max(c.start_date)::date ,
                        '1 month') as series1
       from plan1234
	   left join customers c using (customer_id)
       group by 1
       order by 1,2)


select tb1.customer_id,tb1.series1 as paymentdate  
 
 from (      
 select * from p1
 union all
 select * from p2
 union all
 select * from p3
 union all 
 select * from p4)tb1

--  select tb1.customer_id,v.price,tb1.series1 as paymentdate  
 
--  from (      
--  select * from p1
--  union all
--  select * from p2
--  union all
--  select * from p3
--  union all 
--  select * from p4)tb1
--  left join (select * from customers 
--             left join foodie_fi.plans using (plan_id))v using (customer_id);
