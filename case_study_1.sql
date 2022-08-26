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

 