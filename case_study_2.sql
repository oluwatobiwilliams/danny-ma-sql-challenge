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
ORDER BY 1;

-- B.4
WITH runner_orders AS (
  SELECT order_id, 
  runner_id, 
  CASE WHEN pickup_time IN ('null','') THEN NULL
      ELSE TO_TIMESTAMP(pickup_time,'YYYY-MM-DD HH24:MI:SS') 
      END AS pickup_time, 
  CASE WHEN distance IN ('null', '') THEN NULL 
  	ELSE TRIM(SPLIT_PART(distance,'km',1)) 
  	END AS distance, 
  duration,
  CASE WHEN cancellation IN ('null', '') OR cancellation IS NULL THEN 0
      ELSE 1 
      END AS cancellation
  FROM pizza_runner.runner_orders
),
pizza_details AS (
  SELECT order_id, customer_id, pizza_ordered, runner_id, 
  pickup_time, 
  distance, duration,
  order_time,
  EXTRACT (epoch FROM (pickup_time - order_time)) AS time_taken_seconds,
  cancellation
  FROM runner_orders
  LEFT JOIN (
    SELECT order_id, customer_id, 
    COUNT(*) AS pizza_ordered,
    MIN(order_time) AS order_time
    FROM pizza_runner.customer_orders
    GROUP BY 1, 2
    ) AS co USING (order_id)
)
SELECT customer_id, AVG(distance::FLOAT) AS avg_km
FROM pizza_details
GROUP BY customer_id;

-- B.5
WITH runner_orders AS (
  SELECT order_id, 
  runner_id, 
  CASE WHEN pickup_time IN ('null','') THEN NULL
      ELSE TO_TIMESTAMP(pickup_time,'YYYY-MM-DD HH24:MI:SS') 
      END AS pickup_time, 
  CASE WHEN distance IN ('null', '') THEN NULL 
  	ELSE TRIM(SPLIT_PART(distance,'km',1)) 
  	END AS distance_km, 
  CASE WHEN duration IN ('null','') THEN NULL 
	ELSE TRIM(SPLIT_PART(duration,'min',1))::INTEGER 
  	END AS duration_mins,
  CASE WHEN cancellation IN ('null', '') OR cancellation IS NULL THEN 0
      ELSE 1 
      END AS cancellation
  FROM pizza_runner.runner_orders
)
SELECT  MAX(duration_mins) AS longest_delivery,
MIN(duration_mins) AS shortest_delivery,
MAX(duration_mins) - MIN(duration_mins) AS difference
FROM runner_orders;

-- B.6
-- Avg speed (km/hr) tends to increase for each delivered order after the first delivery
WITH runner_orders AS (
  SELECT order_id, 
  runner_id, 
  CASE WHEN pickup_time IN ('null','') THEN NULL
      ELSE TO_TIMESTAMP(pickup_time,'YYYY-MM-DD HH24:MI:SS') 
      END AS pickup_time, 
  CASE WHEN distance IN ('null', '') THEN NULL 
  	ELSE TRIM(SPLIT_PART(distance,'km',1)) 
  	END AS distance_km, 
  CASE WHEN duration IN ('null','') THEN NULL 
	ELSE TRIM(SPLIT_PART(duration,'min',1))::INTEGER 
  	END AS duration_mins,
  CASE WHEN cancellation IN ('null', '') OR cancellation IS NULL THEN 0
      ELSE 1 
      END AS cancellation
  FROM pizza_runner.runner_orders
)
SELECT runner_id,
order_id,
distance_km::FLOAT/(duration_mins/60.0) AS km_per_hr
FROM runner_orders
WHERE cancellation = 0
ORDER BY runner_id;

-- B.7
WITH runner_orders AS (
  SELECT order_id, 
  runner_id, 
  CASE WHEN pickup_time IN ('null','') THEN NULL
      ELSE TO_TIMESTAMP(pickup_time,'YYYY-MM-DD HH24:MI:SS') 
      END AS pickup_time, 
  CASE WHEN distance IN ('null', '') THEN NULL 
  	ELSE TRIM(SPLIT_PART(distance,'km',1)) 
  	END AS distance_km, 
  CASE WHEN duration IN ('null','') THEN NULL 
	ELSE TRIM(SPLIT_PART(duration,'min',1))::INTEGER 
  	END AS duration_mins,
  CASE WHEN cancellation IN ('null', '') OR cancellation IS NULL THEN 0
      ELSE 1 
      END AS cancellation
  FROM pizza_runner.runner_orders
)
SELECT runner_id,
COUNT(CASE WHEN cancellation = 0 THEN cancellation END) AS successful,
COUNT(*) AS orders,
COUNT(CASE WHEN cancellation = 0 THEN cancellation END)/COUNT(*)::FLOAT AS percent_successful
FROM runner_orders
GROUP BY 1;

/*
C. Ingredient Optimisation

1. What are the standard ingredients for each pizza?
2. What was the most commonly added extra?
3. What was the most common exclusion?
4. Generate an order item for each record in the customers_orders table in the format of one of the following:
Meat Lovers
Meat Lovers - Exclude Beef
Meat Lovers - Extra Bacon
Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

6. What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
*/

-- C.1
WITH topping_unnest AS (
  SELECT pizza_id,
  UNNEST(STRING_TO_ARRAY(toppings, ', '))::INTEGER AS topping_id
  FROM pizza_runner.pizza_recipes
),
toppings AS (
  SELECT t.*, topping_name
  FROM topping_unnest t
  LEFT JOIN pizza_runner.pizza_toppings USING (topping_id)
)
SELECT pizza_id, 
STRING_AGG (topping_name, ', ') AS ingredients
FROM toppings
GROUP BY pizza_id ORDER BY 1;

-- C.2
WITH orders_extra AS (
  SELECT order_id, UNNEST(STRING_TO_ARRAY(extras, ', ')) AS extras
  FROM pizza_runner.customer_orders 
)
SELECT topping_name, COUNT(*) AS no_of_times
FROM (
  SELECT order_id, 
  CASE WHEN extras = 'null' THEN NULL ELSE extras END AS extras
  FROM orders_extra
) AS temp_table
INNER JOIN pizza_runner.pizza_toppings p
ON temp_table.extras::INTEGER = p.topping_id
WHERE extras IS NOT NULL
GROUP BY topping_name
ORDER BY no_of_times DESC
LIMIT 1;

-- C.3
WITH orders_extra AS (
  SELECT order_id, UNNEST(STRING_TO_ARRAY(exclusions, ', ')) AS exclusions
  FROM pizza_runner.customer_orders 
)
SELECT topping_name, COUNT(*) AS no_of_times
FROM (
  SELECT order_id, 
  CASE WHEN exclusions = 'null' THEN NULL ELSE exclusions END AS exclusions
  FROM orders_extra
) AS temp_table
INNER JOIN pizza_runner.pizza_toppings p
ON temp_table.exclusions::INTEGER = p.topping_id
WHERE exclusions IS NOT NULL
GROUP BY topping_name
ORDER BY no_of_times DESC
LIMIT 1;

-- C.4
WITH orders AS (
  SELECT *, ROW_NUMBER() OVER () AS row_index
  FROM pizza_runner.customer_orders
),
exclusions AS (
  SELECT order_id, pizza_id, row_index, topping_name
  FROM (
    SELECT * FROM (
    	SELECT order_id, pizza_id, row_index,
        UNNEST(STRING_TO_ARRAY(exclusions, ', ')) AS exclusions
        FROM orders
    ) AS tmp
    WHERE exclusions NOT IN ('null' ,'')
  ) AS temp_table
  LEFT JOIN pizza_runner.pizza_toppings p
  ON temp_table.exclusions::INTEGER = p.topping_id
  
),
extras AS (
  SELECT order_id, pizza_id, row_index, topping_name
  FROM (
    SELECT * FROM (
    	SELECT order_id, pizza_id, row_index,
        UNNEST(STRING_TO_ARRAY(extras, ', ')) AS extras
        FROM orders
    ) AS tmp
    WHERE extras NOT IN ('null', '')
  ) AS temp_table
  LEFT JOIN pizza_runner.pizza_toppings p
  ON temp_table.extras::INTEGER = p.topping_id
  
),
exclusions_toppings AS (
  SELECT row_index, 
  STRING_AGG(topping_name, ', ') AS exclusions 
  FROM exclusions
  GROUP BY 1
),
extras_toppings AS (
  SELECT row_index, 
  STRING_AGG(topping_name, ', ') AS extras 
  FROM extras
  GROUP BY 1
)
SELECT CONCAT(pizza_name, 
              CASE WHEN t.exclusions IS NULL THEN '' ELSE ' - Exclude ' END, 
              t.exclusions,
             CASE WHEN e.extras IS NULL THEN '' ELSE ' - Exclude ' END,
              e.extras
             ) AS pizza_ordered 
FROM orders o
LEFT JOIN exclusions_toppings t USING (row_index)
LEFT JOIN extras_toppings e USING (row_index)
LEFT JOIN pizza_runner.pizza_names p USING (pizza_id);

-- C.5
WITH orders AS (
  SELECT *, ROW_NUMBER() OVER () AS row_index
  FROM pizza_runner.customer_orders
),
exclusions AS (
  SELECT order_id, pizza_id, row_index, topping_name
  FROM (
    SELECT * FROM (
    	SELECT order_id, pizza_id, row_index,
        UNNEST(STRING_TO_ARRAY(exclusions, ', ')) AS exclusions
        FROM orders
    ) AS tmp
    WHERE exclusions NOT IN ('null' ,'')
  ) AS temp_table
  LEFT JOIN pizza_runner.pizza_toppings p
  ON temp_table.exclusions::INTEGER = p.topping_id
  
),
extras AS (
  SELECT order_id, pizza_id, row_index, topping_name
  FROM (
    SELECT * FROM (
    	SELECT order_id, pizza_id, row_index,
        UNNEST(STRING_TO_ARRAY(extras, ', ')) AS extras
        FROM orders
    ) AS tmp
    WHERE extras NOT IN ('null', '')
  ) AS temp_table
  LEFT JOIN pizza_runner.pizza_toppings p
  ON temp_table.extras::INTEGER = p.topping_id
  
),
exclusions_toppings AS (
  SELECT row_index,
  pizza_id,
  topping_name, 
  CONCAT(row_index,',',topping_name) AS row_index_toppings
  FROM exclusions
)
,
toppings_unnest AS (
  SELECT row_index, pizza_id, UNNEST(STRING_TO_ARRAY(toppings, ', ')) AS toppings 
  FROM orders AS o
  LEFT JOIN pizza_runner.pizza_recipes USING (pizza_id)
  ORDER BY row_index
),
orders_array AS (
  SELECT row_index, pizza_id, 
  CONCAT(row_index,',',topping_name) AS row_index_toppings
  FROM  toppings_unnest u
  JOIN pizza_runner.pizza_toppings t
  ON u.toppings::INTEGER = t.topping_id
  --GROUP BY row_index
  ORDER BY row_index
),
pizza_ingredients AS (
  SELECT * FROM (
    SELECT row_index, pizza_id,
    SPLIT_PART(row_index_toppings,',',2) AS topping_name
    FROM orders_array o
    WHERE row_index_toppings NOT IN (SELECT row_index_toppings FROM exclusions_toppings)

    UNION ALL

    SELECT row_index, pizza_id, topping_name 
    FROM extras  
 ) AS pz
  ORDER BY row_index, pizza_id, topping_name
  )
  
SELECT CONCAT(pizza_name,': ', topping_name) AS ingredient_list
FROM (
  SELECT row_index, pizza_id,
  STRING_AGG(
    CASE WHEN multiplier = 1 THEN topping_name
    ELSE CONCAT(multiplier,'x',topping_name) END, ', ') AS topping_name
  FROM (
    SELECT row_index, pizza_id, topping_name, COUNT(*) AS multiplier 
    FROM pizza_ingredients
    GROUP BY 1, 2, 3
  ) AS tmp
  GROUP BY row_index, pizza_id
) AS tmp
LEFT JOIN pizza_runner.pizza_names USING (pizza_id)
ORDER BY row_index;

-- C.6
WITH delivered_orders AS (
  SELECT order_id FROM (
    SELECT order_id,
  	CASE WHEN cancellation = 'null' THEN 0
      WHEN cancellation IS NULL THEN 0
      WHEN cancellation = '' THEN 0
      ELSE 1 END AS cancellation
  	FROM pizza_runner.runner_orders
  ) AS tmp
  WHERE cancellation = 0
 ), 
orders AS (
  SELECT *, ROW_NUMBER() OVER () AS row_index
  FROM pizza_runner.customer_orders
  WHERE order_id IN (SELECT order_id FROM delivered_orders)
),
exclusions AS (
  SELECT order_id, pizza_id, row_index, topping_name
  FROM (
    SELECT * FROM (
    	SELECT order_id, pizza_id, row_index,
        UNNEST(STRING_TO_ARRAY(exclusions, ', ')) AS exclusions
        FROM orders
    ) AS tmp
    WHERE exclusions NOT IN ('null' ,'')
  ) AS temp_table
  LEFT JOIN pizza_runner.pizza_toppings p
  ON temp_table.exclusions::INTEGER = p.topping_id
  
),
extras AS (
  SELECT order_id, pizza_id, row_index, topping_name
  FROM (
    SELECT * FROM (
    	SELECT order_id, pizza_id, row_index,
        UNNEST(STRING_TO_ARRAY(extras, ', ')) AS extras
        FROM orders
    ) AS tmp
    WHERE extras NOT IN ('null', '')
  ) AS temp_table
  LEFT JOIN pizza_runner.pizza_toppings p
  ON temp_table.extras::INTEGER = p.topping_id
  
),
exclusions_toppings AS (
  SELECT row_index,
  pizza_id,
  topping_name, 
  CONCAT(row_index,',',topping_name) AS row_index_toppings
  FROM exclusions
)
,
toppings_unnest AS (
  SELECT row_index, pizza_id, UNNEST(STRING_TO_ARRAY(toppings, ', ')) AS toppings 
  FROM orders AS o
  LEFT JOIN pizza_runner.pizza_recipes USING (pizza_id)
  ORDER BY row_index
),
orders_array AS (
  SELECT row_index, pizza_id, 
  CONCAT(row_index,',',topping_name) AS row_index_toppings
  FROM  toppings_unnest u
  JOIN pizza_runner.pizza_toppings t
  ON u.toppings::INTEGER = t.topping_id
  ORDER BY row_index
),
pizza_ingredients AS (
  SELECT * FROM (
    SELECT row_index, pizza_id,
    SPLIT_PART(row_index_toppings,',',2) AS topping_name
    FROM orders_array o
    WHERE row_index_toppings NOT IN (SELECT row_index_toppings FROM exclusions_toppings)

    UNION ALL

    SELECT row_index, pizza_id, topping_name 
    FROM extras  
 ) AS pz
  ORDER BY row_index, pizza_id, topping_name
  )
 
 SELECT topping_name, COUNT(*) AS total_quantity 
 FROM pizza_ingredients
 GROUP BY topping_name 
 ORDER BY total_quantity DESC;

/*
D. Pricing and Ratings

1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?
2. What if there was an additional $1 charge for any pizza extras?
Add cheese is $1 extra
3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
    customer_id
    order_id
    runner_id
    rating
    order_time
    pickup_time
    Time between order and pickup
    Delivery duration
    Average speed
    Total number of pizzas
5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
*/


-- D.1
WITH pizza_costs AS (
SELECT 1::INTEGER AS pizza_id, 12::INTEGER AS amount
  UNION ALL
SELECT 2::INTEGER AS pizza_id, 10::INTEGER AS amount
),
deliveries AS (
  SELECT order_id, 
  CASE WHEN cancellation IN ('null', '') THEN 0  
  	 WHEN cancellation IS NULL THEN 0 
  ELSE 1 END AS cancellation
  FROM pizza_runner.runner_orders
)
SELECT SUM(amount) AS total_sales
FROM pizza_runner.customer_orders
LEFT JOIN pizza_costs USING (pizza_id)
WHERE order_id IN (SELECT order_id FROM deliveries WHERE cancellation = 0);

-- D.2 

WITH pizza_costs AS (
SELECT 1::INTEGER AS pizza_id, 12::INTEGER AS amount
  UNION ALL
SELECT 2::INTEGER AS pizza_id, 10::INTEGER AS amount
),
customer_orders AS (
  SELECT order_id,
    customer_id,
    pizza_id,
    CASE WHEN extras IN ('null', '') THEN NULL  
    ELSE extras END AS extras
  FROM pizza_runner.customer_orders
),
deliveries AS (
  SELECT order_id, 
  CASE WHEN cancellation IN ('null', '') THEN 0  
  	 WHEN cancellation IS NULL THEN 0 
  ELSE 1 END AS cancellation
  FROM pizza_runner.runner_orders
)

SELECT SUM(amount) + SUM(no_of_extras) AS total_amount
FROM
(
  SELECT order_id,
  amount, 
  extras,
  ARRAY_LENGTH(STRING_TO_ARRAY(extras, ', '),1) AS no_of_extras
  FROM customer_orders
  LEFT JOIN pizza_costs USING (pizza_id)
  WHERE order_id IN (SELECT order_id FROM deliveries WHERE cancellation = 0) 
) AS tmp;

