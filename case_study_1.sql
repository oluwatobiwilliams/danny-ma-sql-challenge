/* --------------------
   Case Study Questions
   --------------------*/
---Tables
--  sales
--  members
--  menu

-- 1. What is the total amount each customer spent at the restaurant?
-- 2. How many days has each customer visited the restaurant?
-- 3. What was the first item from the menu purchased by each customer?
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- 5. Which item was the most popular for each customer?
-- 6. Which item was purchased first by the customer after they became a member?
-- 7. Which item was purchased just before the customer became a member?
-- 8. What is the total items and amount spent for each member before they became a member?
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

-- QUESTION 1 answer
SELECT s.customer_id, SUM(m.price) AS total_amount
FROM dannys_diner.sales AS s
LEFT JOIN dannys_diner.menu AS m
USING (product_id)
GROUP BY 1;

-- QUESTION 2 answer
SELECT customer_id, COUNT(DISTINCT order_date) AS no_of_days 
FROM dannys_diner.sales
GROUP BY customer_id;

-- QUESTION 3 answer
-- version 1 (assuming first item = first basket of goods)
SELECT customer_id, product_name
FROM
(
  SELECT s.customer_id, 
  m.product_name,
  RANK() OVER (PARTITION BY customer_id ORDER BY order_date) AS sales_rank
  FROM dannys_diner.sales AS s
  LEFT JOIN dannys_diner.menu AS m
  USING (product_id)
) AS temp_table
 WHERE sales_rank = 1;
 
 -- version 1 alternative
WITH first_sales AS (
   SELECT customer_id, MIN(order_date) AS first_date
   FROM dannys_diner.sales
   GROUP BY customer_id
)
SELECT s.customer_id, product_name
FROM dannys_diner.sales AS s
INNER JOIN first_sales AS f ON s.order_date = f.first_date AND s.customer_id = f.customer_id
INNER JOIN dannys_diner.menu USING (product_id)
ORDER BY 1;

 -- version 2 (assuming first item = first product in the basket)
SELECT customer_id, product_name
FROM
(
  SELECT s.customer_id, 
  m.product_name,
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date) AS sales_rank
  FROM dannys_diner.sales AS s
  LEFT JOIN dannys_diner.menu AS m
  USING (product_id)
 ) AS temp_table
 WHERE sales_rank = 1;

 -- QUESTION 4 answer
SELECT product_name, COUNT(*) AS no_of_times_purchased
FROM dannys_diner.sales
INNER JOIN dannys_diner.menu USING (product_id)
GROUP BY product_name
ORDER BY no_of_times_purchased DESC
LIMIT 1;

-- QUESTION 5 answer
WITH products_purchased AS (
  SELECT customer_id, product_name, COUNT(*) AS no_of_times_purchased
  FROM dannys_diner.sales
  INNER JOIN dannys_diner.menu USING (product_id)
  GROUP BY customer_id, product_name
  ORDER BY customer_id, no_of_times_purchased DESC
)
SELECT customer_id, product_name
FROM 
(
  SELECT p.*,
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY no_of_times_purchased DESC) AS rank_item
  FROM products_purchased p
) AS temp
WHERE rank_item = 1; 

-- QUESTION 6 answer
SELECT customer_id, product_name
FROM (
  SELECT  members.*, product_name,
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date ASC) AS row_num
  FROM(
    SELECT s.customer_id, s.product_id, order_date, join_date
    FROM dannys_diner.sales s
    INNER JOIN dannys_diner.members m
    ON s.customer_id = m.customer_id 
    AND s.order_date > m.join_date
  ) AS members
  INNER JOIN dannys_diner.menu USING (product_id)
) AS customers
WHERE row_num = 1;

-- QUESTION 7 answer
SELECT customer_id, product_name
FROM (
  SELECT  members.*, product_name,
  ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY order_date DESC) AS row_num
  FROM(
    SELECT s.customer_id, s.product_id, order_date, join_date
    FROM dannys_diner.sales s
    INNER JOIN dannys_diner.members m
    ON s.customer_id = m.customer_id 
    AND s.order_date < m.join_date
  ) AS members
  INNER JOIN dannys_diner.menu USING (product_id)
) AS customers
WHERE row_num = 1;

-- QUESTION 8 answer
WITH members AS (
  SELECT s.customer_id, s.product_id, price
  FROM dannys_diner.sales s
  INNER JOIN dannys_diner.members m
  ON s.customer_id = m.customer_id 
  AND s.order_date < m.join_date
  INNER JOIN dannys_diner.menu e USING (product_id)
)
SELECT customer_id, COUNT(*) AS no_of_items,
SUM(price) AS total_amount
FROM members
GROUP BY customer_id;

-- QUESTION 9 answer
WITH points AS (
  SELECT customer_id, s.product_id, price,
  CASE WHEN product_id = 1 THEN price*20 ELSE price*10 
      END AS points
  FROM dannys_diner.sales s
  INNER JOIN dannys_diner.menu m USING (product_id)
)
SELECT customer_id, SUM(points) AS total_points
FROM points
GROUP BY customer_id
ORDER BY total_points DESC;

-- QUESTION 10 answer
WITH members AS (
SELECT s.customer_id, s.product_id, order_date, join_date
    FROM dannys_diner.sales s
    INNER JOIN dannys_diner.members m
    ON s.customer_id = m.customer_id 
    AND s.order_date >= m.join_date
)
SELECT customer_id,
SUM(CASE 
    WHEN order_date < join_date+INTERVAL '7 day' THEN price*20 
    WHEN product_id=1 THEN price*20
    ELSE price*10
	END) AS points
FROM members
INNER JOIN dannys_diner.menu USING (product_id)
WHERE order_date <= '2021-01-31'
GROUP BY 1
