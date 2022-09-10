/*
A. Customer Nodes Exploration
1. How many unique nodes are there on the Data Bank system?
2. What is the number of nodes per region?
3. How many customers are allocated to each region?
4. How many days on average are customers reallocated to a different node?
5. What is the median, 80th and 95th percentile for this same reallocation days metric for each region?
*/

-- A.1
SELECT DISTINCT node_id
FROM data_bank.customer_nodes;

-- A.2
SELECT region_id, COUNT(DISTINCT node_id) AS no_of_nodes
FROM data_bank.customer_nodes
GROUP BY region_id ORDER BY region_id;

-- A.3
SELECT region_id, COUNT(DISTINCT customer_id) AS no_of_nodes
FROM data_bank.customer_nodes
GROUP BY 1 ORDER BY region_id;

-- A.4
SELECT ROUND(AVG(end_date - start_date),1) AS avg_node_days 
FROM (
  SELECT customer_id, 
  start_date, 
  CASE WHEN end_date>CURRENT_DATE THEN '2020-12-31'::DATE ELSE end_date END AS end_date,
  region_id,
  node_id
  FROM data_bank.customer_nodes
) AS tmp;

-- A.5
WITH customer_nodes AS (
  SELECT *, end_date - start_date AS node_days 
  FROM (
    SELECT customer_id, 
    start_date, 
    CASE WHEN end_date>CURRENT_DATE THEN '2020-12-31'::DATE ELSE end_date END AS end_date,
    region_id,
    node_id
    FROM data_bank.customer_nodes
  ) AS tmp
)
SELECT region_id, 
PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY node_days) AS median,
ROUND(PERCENTILE_CONT(0.8) WITHIN GROUP (ORDER BY node_days)::NUMERIC,1) AS percentile_80,
ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY node_days)::NUMERIC,1) AS percentile_95
FROM customer_nodes
GROUP BY region_id;



