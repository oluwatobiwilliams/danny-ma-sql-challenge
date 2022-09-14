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

/*
B. Customer Transactions
1. What is the unique count and total amount for each transaction type?
2. What is the average total historical deposit counts and amounts for all customers?
3. For each month - how many Data Bank customers make more than 1 deposit and either 1 purchase or 1 withdrawal in a single month?
4. What is the closing balance for each customer at the end of the month?
5. What is the percentage of customers who increase their closing balance by more than 5%?
*/

-- B.1
SELECT txn_type, COUNT(*) AS no_of_transactions, SUM(txn_amount) AS total_amount 
FROM data_bank.customer_transactions
GROUP BY txn_type;

-- B.2
SELECT ROUND(AVG(no_of_transactions),1) AS avg_deposit_txn_count,
ROUND(AVG(total_amount),1) AS avg_total_deposit
FROM (
  SELECT customer_id, 
  COUNT(*) AS no_of_transactions, 
  SUM(txn_amount) AS total_amount 
  FROM data_bank.customer_transactions
  WHERE txn_type = 'deposit'
  GROUP BY customer_id
) AS tmp
;

-- B.3
SELECT txn_month,
COUNT(CASE WHEN deposit_count>1 AND (withdrawal_count>1 OR purchase_count>1) THEN customer_id END) AS no_of_customers
FROM (
  SELECT customer_id, 
  DATE_TRUNC('month', txn_date) AS txn_month,
  COUNT(CASE WHEN txn_type = 'deposit' THEN 1 END) AS deposit_count,
  COUNT(CASE WHEN txn_type = 'withdrawal' THEN 1 END) AS withdrawal_count,
  COUNT(CASE WHEN txn_type = 'purchase' THEN 1 END) AS purchase_count
  FROM data_bank.customer_transactions
  GROUP BY customer_id, txn_month
) AS tmp
GROUP BY txn_month ORDER BY txn_month
;

-- B.4
SELECT *,
SUM(txn_amount) OVER (PARTITION BY customer_id ORDER BY month_ ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS balance

FROM
(SELECT customer_id,DATE_TRUNC('Month',txn_date) AS month_, SUM(txn_group)AS txn_amount 
FROM
  (SELECT *,
  CASE WHEN txn_type = 'deposit' THEN txn_amount
  ELSE -1 * txn_amount END AS txn_group
  FROM data_bank.Customer_Transactions
  ORDER BY customer_id, txn_date
  ) AS tmp1
GROUP BY 1,2
ORDER BY 1,2 
)AS tmp2
ORDER BY customer_id, month_
;

--B.5
WITH customer_balance AS (
  SELECT *,
  SUM(txn_amount) OVER (PARTITION BY customer_id ORDER BY month_ ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS balance
  FROM (
    SELECT customer_id,DATE_TRUNC('Month',txn_date) AS month_, SUM(txn_group)AS txn_amount 
    FROM (
      SELECT *,
      CASE WHEN txn_type = 'deposit' THEN txn_amount
        ELSE -1 * txn_amount END AS txn_group
        FROM data_bank.Customer_Transactions
        ORDER BY customer_id, txn_date
    ) AS update_txn_amount
    GROUP BY 1,2
  ) AS monthly_totals
),
growth_rates AS (
  SELECT customer_id, month_, balance, previous_month_balance, 
  CASE WHEN previous_month_balance IS NULL THEN NULL
  		WHEN previous_month_balance = 0 THEN balance*100
  ELSE ROUND(((balance-(previous_month_balance))/ABS(previous_month_balance))*100,1) END AS growth_rate,
  ROW_NUMBER () OVER (PARTITION BY customer_id ORDER BY month_ DESC) AS balance_index
  FROM (
      SELECT *,
      LAG(balance) OVER (PARTITION BY customer_id ORDER BY month_) AS previous_month_balance
      FROM customer_balance
      ) AS add_previous_month_balance
),
cust_last_balance AS (
  SELECT customer_id, month_, growth_rate,
  CASE WHEN growth_rate > 5 THEN 1 ELSE 0 END AS growth_rate_check 
  FROM growth_rates
  WHERE balance_index = 1
)

SELECT (SUM(growth_rate_check)/COUNT(*)::FLOAT)*100
FROM cust_last_balance;

/*
C. Data Allocation Challenge
To test out a few different hypotheses - the Data Bank team wants to run an experiment where different groups of customers would be allocated data using 3 different options:

Option 1: data is allocated based off the amount of money at the end of the previous month
Option 2: data is allocated on the average amount of money kept in the account in the previous 30 days
Option 3: data is updated real-time
For this multi-part challenge question - you have been requested to generate the following data elements to help the Data Bank team estimate how much data will need to be provisioned for each option:

1. running customer balance column that includes the impact each transaction
2. customer balance at the end of each month
3. minimum, average and maximum values of the running balance for each customer
Using all of the data available - how much data would have been required for each option on a monthly basis?
*/

-- C.1 option 1
WITH customer_balance AS (
  SELECT *,
  SUM(txn_amount) OVER (PARTITION BY customer_id ORDER BY month_ ASC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS balance
  FROM (
    SELECT customer_id,DATE_TRUNC('Month',txn_date) AS month_, SUM(txn_group)AS txn_amount 
    FROM (
      SELECT *,
      CASE WHEN txn_type = 'deposit' THEN txn_amount
        ELSE -1 * txn_amount END AS txn_group
        FROM data_bank.Customer_Transactions
        ORDER BY customer_id, txn_date
    ) AS update_txn_amount
    GROUP BY 1,2
  ) AS monthly_totals
),
growth_rates AS (
  SELECT customer_id, month_, balance, previous_month_balance,
  -- option 1 data storage
  CASE WHEN previous_month_balance < 0 THEN 0 ELSE previous_month_balance END AS data_storage,
  CASE WHEN previous_month_balance IS NULL THEN NULL
  		WHEN previous_month_balance = 0 THEN balance*100
  ELSE ROUND(((balance-(previous_month_balance))/ABS(previous_month_balance))*100,1) END AS growth_rate,
  ROW_NUMBER () OVER (PARTITION BY customer_id ORDER BY month_ DESC) AS balance_index
  FROM (
      SELECT *,
      LAG(balance) OVER (PARTITION BY customer_id ORDER BY month_) AS previous_month_balance
      FROM customer_balance
      ) AS add_previous_month_balance
)

SELECT month_, SUM(data_storage) AS total_data_storage
FROM growth_rates
GROUP BY month_
ORDER BY month_


-- C.2 option 2
WITH customer_txn AS (
  SELECT *,
  CASE WHEN txn_type = 'deposit' THEN txn_amount
  ELSE -1 * txn_amount END AS txn_group
  FROM data_bank.customer_transactions
 ),
customer_date_series AS (
  SELECT customer_id,
  GENERATE_SERIES(first_date, last_date, '1 day') AS date_series
  FROM (
    SELECT customer_id, MIN(txn_date) AS first_date, MAX(txn_date) AS last_date
    FROM customer_txn
    GROUP BY customer_id
  )  AS generate_min_max
)

SELECT *, 
SUM(txn_group) OVER (PARTITION BY customer_id ORDER BY date_series) AS txn_cf
FROM (
  SELECT s.customer_id, date_series, txn_group,
  COUNT(txn_group) OVER (PARTITION BY s.customer_id ORDER BY date_series) AS txn_count
  FROM customer_date_series s
  LEFT JOIN customer_txn b ON s.customer_id = b.customer_id AND s.date_series = b.txn_date 
  ORDER BY s.customer_id, date_series
) AS generate_txn_count
LIMIT 400

