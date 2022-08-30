/*
A. Pizza Metrics

1. How many pizzas were ordered?
2. How many unique customer orders were made?
3. How many successful orders were delivered by each runner?
4. How many of each type of pizza was delivered?
5. How many Vegetarian and Meatlovers were ordered by each customer?
6. What was the maximum number of pizzas delivered in a single order?
7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
8. How many pizzas were delivered that had both exclusions and extras?
9. What was the total volume of pizzas ordered for each hour of the day?
10. What was the volume of orders for each day of the week?
*/

-- A.1
SELECT COUNT(pizza_id) AS total_pizzas
FROM pizza_runner.customer_orders;

-- A.2
SELECT COUNT(DISTINCT order_id) AS unique_customer_orders
FROM pizza_runner.customer_orders;

-- A.3
WITH cleaned_orders AS (
    SELECT order_id, runner_id, pickup_time, distance, duration,
  	CASE WHEN cancellation = 'null' THEN 0
      WHEN cancellation IS NULL THEN 0
      WHEN cancellation = '' THEN 0
      ELSE 1 END AS cancellation
  	FROM pizza_runner.runner_orders
)
SELECT COUNT(*) AS delivered_orders
FROM cleaned_orders
WHERE cancellation = 0;

-- A.4
WITH cleaned_orders AS (
    SELECT order_id, runner_id, pickup_time, distance, duration,
  	CASE WHEN cancellation = 'null' THEN 0
      WHEN cancellation IS NULL THEN 0
      WHEN cancellation = '' THEN 0
      ELSE 1 END AS cancellation
  	FROM pizza_runner.runner_orders
)
SELECT pizza_id, COUNT(*) AS no_of_pizzas
FROM(
  SELECT c.*, o.cancellation 
  FROM pizza_runner.customer_orders AS c
  LEFT JOIN cleaned_orders AS o USING (order_id)
) AS temp_table
WHERE cancellation = 0
GROUP BY pizza_id;

-- A.5
SELECT customer_id,
COALESCE(SUM(CASE WHEN pizza_id = 1 THEN 1 END),0) AS meatlovers,
COALESCE(SUM(CASE WHEN pizza_id = 2 THEN 1 END),0) AS vegetarian
FROM pizza_runner.customer_orders
GROUP BY customer_id;

-- A.6
SELECT order_id, COUNT(*) AS pizzas_delivered 
FROM pizza_runner.customer_orders
WHERE order_id IN (
	SELECT DISTINCT order_id 
  	FROM (
  		SELECT order_id, runner_id, pickup_time, distance, duration,
 			CASE WHEN cancellation IN ('null', '') OR cancellation IS NULL THEN 0
    		ELSE 1 END AS cancellation
  		FROM pizza_runner.runner_orders
	) AS runner_orders
	WHERE cancellation = 0
)
GROUP BY order_id
ORDER BY pizzas_delivered DESC;

-- A.7
WITH cleaned_orders AS (
  SELECT order_id, customer_id, pizza_id,
  CASE WHEN exclusions IN ('null','') THEN null ELSE exclusions END AS exclusions,
  CASE WHEN extras IN ('null','') THEN null ELSE extras END AS extras,
  order_time
  FROM pizza_runner.customer_orders
),
runner_orders AS (
  SELECT order_id, runner_id, pickup_time, distance, duration,
  CASE WHEN cancellation IN ('null', '') OR cancellation IS NULL THEN 0
  	ELSE 1 END AS cancellation
  FROM pizza_runner.runner_orders
)
SELECT customer_id, 
COUNT(CASE WHEN change = 0 THEN 0 END) AS pizza_no_change,
COUNT(CASE WHEN change = 1 THEN 1 END) AS pizza_with_change
FROM (
  	SELECT c.*,
		  CASE WHEN exclusions IS NULL AND extras IS NULL THEN 0 ELSE 1 END AS change
	  FROM cleaned_orders AS c
	  WHERE order_id IN (SELECT order_id FROM runner_orders WHERE cancellation = 0)
) AS pizza_changes
GROUP BY 1;

-- A.8
WITH cleaned_orders AS (
  SELECT order_id, customer_id, pizza_id,
  CASE WHEN exclusions IN ('null','') THEN null ELSE exclusions END AS exclusions,
  CASE WHEN extras IN ('null','') THEN null ELSE extras END AS extras,
  order_time
  FROM pizza_runner.customer_orders
),
runner_orders AS (
  SELECT order_id, runner_id, pickup_time, distance, duration,
  CASE WHEN cancellation IN ('null', '') OR cancellation IS NULL THEN 0
  	ELSE 1 END AS cancellation
  FROM pizza_runner.runner_orders
)
SELECT COUNT(*) AS pizza_delivered 
FROM (
  SELECT c.*,
  CASE WHEN exclusions IS NOT NULL AND extras IS NOT NULL 
      THEN 1 ELSE 0 END AS both_ex
  FROM cleaned_orders AS c
  WHERE order_id IN (SELECT order_id FROM runner_orders WHERE cancellation = 0)
 ) AS check_both_ex
 WHERE both_ex = 1;

 -- A.9
SELECT EXTRACT(hour FROM order_time) AS hod,
COUNT(*) AS pizza_ordered
FROM pizza_runner.customer_orders
GROUP BY hod
ORDER BY pizza_ordered DESC;

-- A.10
SELECT TO_CHAR(order_time,'Day') AS dow,
EXTRACT(dow FROM order_time) AS dow_2,
COUNT(*) AS pizza_ordered
FROM pizza_runner.customer_orders
GROUP BY 1, 2
ORDER BY pizza_ordered DESC;

/*
B. Runner and Customer Experience

1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
4. What was the average distance travelled for each customer?
5. What was the difference between the longest and shortest delivery times for all orders?
6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
7. What is the successful delivery percentage for each runner?
*/

-- B.1
SELECT 
   CONCAT('Week ', to_char(registration_date, 'WW')) AS registration_week,  -- the 'WW' argument returns the week number of year(the first week starts on the first day of the year)
   COUNT(runner_id) AS runners_registered
FROM pizza_runner.runners
     AS runner_sign_date
GROUP BY 1
ORDER BY 1;

-- B.2
WITH runner_orders AS (
  SELECT order_id, 
  runner_id, 
  CASE WHEN pickup_time IN ('null','') THEN NULL
      ELSE TO_TIMESTAMP(pickup_time,'YYYY-MM-DD HH24:MI:SS') 
      END AS pickup_time, 
  distance, 
  duration,
  CASE WHEN cancellation IN ('null', '') OR cancellation IS NULL THEN 0
      ELSE 1 
      END AS cancellation
  FROM pizza_runner.runner_orders
)
SELECT runner_id, ROUND(AVG(time_taken_seconds/60.0)) AS avg_minutes
FROM(
  SELECT order_id, runner_id, pickup_time, order_time,
  EXTRACT (epoch FROM (pickup_time - order_time)) AS time_taken_seconds
  FROM runner_orders
  LEFT JOIN (
      SELECT DISTINCT order_id, order_time
      FROM pizza_runner.customer_orders
          ) AS co
  USING (order_id)
) AS runner_time
GROUP BY runner_id;

-- B.3
-- There exists a positive relationship b/w no of pizzas ordered and the time taken to prepare
WITH runner_orders AS (
  SELECT order_id, 
  runner_id, 
  CASE WHEN pickup_time IN ('null','') THEN NULL
      ELSE TO_TIMESTAMP(pickup_time,'YYYY-MM-DD HH24:MI:SS') 
      END AS pickup_time, 
  distance, 
  duration,
  CASE WHEN cancellation IN ('null', '') OR cancellation IS NULL THEN 0
      ELSE 1 
      END AS cancellation
  FROM pizza_runner.runner_orders
),
pizza_details AS (
  SELECT order_id, pizza_ordered, runner_id, pickup_time, order_time,
  EXTRACT (epoch FROM (pickup_time - order_time)) AS time_taken_seconds
  FROM runner_orders
  LEFT JOIN (
    SELECT order_id, 
    COUNT(*) AS pizza_ordered,
    MIN(order_time) AS order_time
    FROM pizza_runner.customer_orders
    GROUP BY 1
     ) AS co USING (order_id)
)
SELECT pizza_ordered, AVG(time_taken_seconds) AS avg_seconds
FROM pizza_details
GROUP BY 1
ORDER BY 1
