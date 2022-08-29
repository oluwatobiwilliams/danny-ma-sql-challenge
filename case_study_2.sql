/*
A. Pizza Metrics

How many pizzas were ordered?
How many unique customer orders were made?
How many successful orders were delivered by each runner?
How many of each type of pizza was delivered?
How many Vegetarian and Meatlovers were ordered by each customer?
What was the maximum number of pizzas delivered in a single order?
For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
How many pizzas were delivered that had both exclusions and extras?
What was the total volume of pizzas ordered for each hour of the day?
What was the volume of orders for each day of the week?
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