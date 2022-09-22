/*
1. Using the following DDL schema details to create an ERD for all the Clique Bait datasets.
*/

-- 1 Using dbdiagram.io/d
-- Generate ERD for Clique-Bait Seafood Online Store from www.dbdiagram.io

TABLE clique_bait.event_identifier {
  "event_type" INTEGER [pk]
  "event_name" VARCHAR(13)
}

TABLE clique_bait.campaign_identifier {
  "campaign_id" INTEGER
  "products" VARCHAR(3)
  "campaign_name" VARCHAR(33)
  "start_date" TIMESTAMP
  "end_date" TIMESTAMP
}

TABLE clique_bait.page_hierarchy {
  "page_id" INTEGER [pk]
  "page_name" VARCHAR(14)
  "product_category" VARCHAR(9)
  "product_id" INTEGER
}

TABLE clique_bait.users {
  "user_id" INTEGER
  "cookie_id" VARCHAR(6)
  "start_date" DATE
  INDEXES {
    (cookie_id, start_date) [pk]
  }
}

TABLE clique_bait.events {
  "visit_id" VARCHAR(6) [pk]
  "cookie_id" VARCHAR(6)
  "page_id" INTEGER
  "event_type" INTEGER
  "sequence_number" INTEGER
  "event_time" TIMESTAMP
}

REF: clique_bait.events.event_type > clique_bait.event_identifier.event_type
REF: clique_bait.events.page_id > clique_bait.page_hierarchy.page_id
REF: clique_bait.events.(cookie_id, event_time) > clique_bait.users.(cookie_id, start_date)

/*
2. Digital Analysis
Using the available datasets - answer the following questions using a single query for each one:

1. How many users are there?
2. How many cookies does each user have on average?
3. What is the unique number of visits by all users per month?
4. What is the number of events for each event type?
5. What is the percentage of visits which have a purchase event?
6. What is the percentage of visits which view the checkout page but do not have a purchase event?
7. What are the top 3 pages by number of views?
8. What is the number of views and cart adds for each product category?
9. What are the top 3 products by purchases?
*/

-- 2.1
SELECT COUNT(DISTINCT user_id) AS no_of_users
FROM clique_bait.users;

-- 2.2
SELECT ROUND(AVG(no_of_cookies),1) AS avg_cookie_per_user
FROM (
  SELECT user_id, COUNT(DISTINCT cookie_id) AS no_of_cookies
  FROM clique_bait.users 
  GROUP BY user_id 
) AS group_users
;

-- 2.3
SELECT month, SUM(unique_visits) AS total_unique_visits 
FROM (
	SELECT user_id, DATE_TRUNC('month', event_time) AS month, COUNT(DISTINCT visit_id) AS unique_visits  
	FROM (
		SELECT e.*, u.user_id 
		FROM clique_bait.events e
		LEFT JOIN clique_bait.users u ON e.event_time::DATE >= u.start_date::DATE
		AND e.cookie_id = u.cookie_id
	) AS add_user_id
	GROUP BY user_id, month
) AS get_unique_visits
GROUP BY 1
ORDER BY 1
;

-- 2.4
SELECT event_type,
COUNT(*) AS no_of_events
FROM clique_bait.events e 
GROUP BY event_type 
ORDER BY no_of_events DESC
;

-- 2.5
SELECT COUNT(CASE WHEN event_type = 3 THEN visit_id END) AS purchase_event,
COUNT(*) AS total_events,
ROUND((COUNT(CASE WHEN event_type = 3 THEN visit_id END)/COUNT(*)::NUMERIC)*100,2) AS percent_purchase_event
FROM clique_bait.events
;

-- 2.6
SELECT *, ROUND((checkout_no_purchase/total_visits::NUMERIC)*100,2) AS percentage_checkout_no_purchase
FROM (
	SELECT COUNT(CASE WHEN page_journey ~ '12' AND page_journey !~ '13' THEN visit_id END) AS checkout_no_purchase,
	COUNT(*) AS total_visits
	FROM (
		SELECT visit_id, STRING_AGG(page_id::TEXT, ',') AS page_journey, STRING_AGG(event_type::TEXT,',') AS events_fired  
		FROM clique_bait.events
		GROUP BY visit_id
	) AS generate_customer_journey
) AS count_checkout_no_purchase
;

-- 2.7
SELECT page_id, COUNT(*) AS no_of_views
FROM clique_bait.events e
WHERE event_type = 1
GROUP BY page_id 
ORDER BY no_of_views DESC LIMIT 3
;

-- 2.8
SELECT product_category,
COUNT(CASE WHEN event_type = 1 THEN 1 END) AS page_views,
COUNT(CASE WHEN event_type = 2 THEN 1 END) AS cart_adds
FROM (
	SELECT page_id, product_category, event_type 
	FROM clique_bait.events e
	LEFT JOIN clique_bait.page_hierarchy ph USING (page_id)
) AS get_product_category
WHERE product_category IS NOT NULL 
GROUP BY product_category
;

-- 2.9
WITH purchases AS (
	SELECT visit_id 
	FROM (
		SELECT visit_id, STRING_AGG(page_id::TEXT, ',') AS page_journey  
		FROM clique_bait.events
		GROUP BY visit_id	
	) AS generate_user_journey
	WHERE page_journey ~ '13'
)
SELECT product_id, page_name, COUNT(*) AS no_of_purchases
FROM (
	SELECT page_id, page_name, product_id, product_category, event_type 
	FROM clique_bait.events e
	LEFT JOIN clique_bait.page_hierarchy ph USING (page_id)
	WHERE visit_id IN (SELECT visit_id FROM purchases)
) AS add_product_id
WHERE event_type = 2
GROUP BY product_id, page_name
ORDER BY no_of_purchases DESC 
LIMIT 3
;


/*
3. Product Funnel Analysis
Using a single SQL query - create a new output table which has the following details:

1. How many times was each product viewed?
2. How many times was each product added to cart?
3. How many times was each product added to a cart but not purchased (abandoned)?
4. How many times was each product purchased?
5. Additionally, create another table which further aggregates the data for the above points but this time for each product category instead of individual products.

Use your 2 new output tables - answer the following questions:

6. Which product had the most views, cart adds and purchases?
7. Which product was most likely to be abandoned?
8. Which product had the highest view to purchase percentage?
9. What is the average conversion rate from view to cart add?
10. What is the average conversion rate from cart add to purchase?
*/

-- 3.1 - 3.4
WITH abandoned AS (
	SELECT visit_id
	FROM (
		SELECT visit_id, STRING_AGG(page_id::TEXT, ',') AS page_journey  
		FROM clique_bait.events
		GROUP BY visit_id	
	) AS generate_user_journey
	WHERE page_journey ~ '12' AND page_journey !~ '13'
),
purchases AS (
	SELECT visit_id 
	FROM (
		SELECT visit_id, STRING_AGG(page_id::TEXT, ',') AS page_journey  
		FROM clique_bait.events
		GROUP BY visit_id	
	) AS generate_user_journey
	WHERE page_journey ~ '13'
)

SELECT product_id, page_name, 
COUNT (CASE WHEN event_type = 1 THEN 1 END) AS total_page_views,
COUNT (CASE WHEN event_type = 2 THEN 1 END) AS total_add_to_cart,
COUNT (CASE WHEN event_type = 2 AND visit_id IN (SELECT visit_id FROM abandoned) THEN 1 END) AS abandoned_add_to_cart,
COUNT (CASE WHEN visit_id IN (SELECT visit_id FROM purchases) AND event_type NOT IN (1,4,5) THEN 1 END) AS purchased_product
FROM (
	SELECT visit_id, page_name, product_id, event_type 
	FROM clique_bait.events e
	LEFT JOIN clique_bait.page_hierarchy ph USING (page_id)
) AS joined_table
WHERE product_id IS NOT NULL
GROUP BY product_id, page_name 
ORDER BY purchased_product DESC
;

-- 3.5 to 3.9
-- Lobster: product with most views, cart adds and purchases
-- Abalone: most likely to be abandoned; a shellfish
-- Lobster: highest purchase-to-view percentage at 48.74%; Russian Caviar is the exact opposite.
WITH abandoned AS (
	SELECT visit_id
	FROM (
		SELECT visit_id, STRING_AGG(page_id::TEXT, ',') AS page_journey  
		FROM clique_bait.events
		GROUP BY visit_id	
	) AS generate_user_journey
	WHERE page_journey ~ '12' AND page_journey !~ '13'
),
purchases AS (
	SELECT visit_id 
	FROM (
		SELECT visit_id, STRING_AGG(page_id::TEXT, ',') AS page_journey  
		FROM clique_bait.events
		GROUP BY visit_id	
	) AS generate_user_journey
	WHERE page_journey ~ '13'
)
SELECT 
ROUND(AVG(cart_adds_to_views),2) AS average_cart_adds_to_views,
ROUND(AVG(purchased_from_add_to_cart),2) AS average_purchased_from_add_to_cart
FROM ( 
	SELECT *,
	ROUND((purchased_product / total_page_views::NUMERIC)*100,2) AS purchase_to_view_percentage,
	(total_add_to_cart / total_page_views::NUMERIC)*100 AS cart_adds_to_views,
	(purchased_product / total_add_to_cart::NUMERIC)*100 AS purchased_from_add_to_cart
	FROM (
		SELECT product_id, page_name, 
		COUNT (CASE WHEN event_type = 1 THEN 1 END) AS total_page_views,
		COUNT (CASE WHEN event_type = 2 THEN 1 END) AS total_add_to_cart,
		COUNT (CASE WHEN event_type = 2 AND visit_id IN (SELECT visit_id FROM abandoned) THEN 1 END) AS abandoned_add_to_cart,
		COUNT (CASE WHEN visit_id IN (SELECT visit_id FROM purchases) AND event_type = 2 THEN 1 END) AS purchased_product
		FROM (
			SELECT visit_id, page_name, product_id, event_type 
			FROM clique_bait.events e
			LEFT JOIN clique_bait.page_hierarchy ph USING (page_id)
		) AS joined_table
		WHERE product_id IS NOT NULL
		GROUP BY product_id, page_name 
		ORDER BY purchased_product DESC
	) AS generate_metrics
	ORDER BY purchase_to_view_percentage DESC 
) AS add_additional_metrics
;

/*
3. Campaigns Analysis
Generate a table that has 1 single row for every unique visit_id record and has the following columns:

user_id
visit_id
visit_start_time: the earliest event_time for each visit
page_views: count of page views for each visit
cart_adds: count of product cart add events for each visit
purchase: 1/0 flag if a purchase event exists for each visit
campaign_name: map the visit to a campaign if the visit_start_time falls between the start_date and end_date
impression: count of ad impressions for each visit
click: count of ad clicks for each visit
(Optional column) cart_products: a comma separated text value with products added to the cart sorted by the order they were added to the cart (hint: use the sequence_number)
*/

SELECT visit_id,
user_id,
visit_start_time,
page_views,
cart_adds,
purchase_flag,
campaign_name,
ad_impressions,
ad_clicks,
cart_products
FROM (
	SELECT visit_id, 
	MIN(user_id) AS user_id, 
	MIN(event_time) AS visit_start_time,
	COUNT(CASE WHEN event_type = 1 THEN 1 END) AS page_views,
	COUNT(CASE WHEN event_type = 2 THEN 1 END) AS cart_adds,
	MAX(CASE WHEN event_type = 3 THEN 1 ELSE 0 END) AS purchase_flag,
	COUNT(CASE WHEN event_type = 4 THEN 1 END) AS ad_impressions,
	COUNT(CASE WHEN event_type = 5 THEN 1 END) AS ad_clicks,
	STRING_AGG(CASE WHEN event_type = 2 THEN product_id::TEXT END, ',') AS cart_products
	FROM (
		SELECT visit_id, user_id, e.cookie_id, page_id, product_id, event_type, sequence_number, event_time 
		FROM clique_bait.events e
		LEFT JOIN clique_bait.users u ON e.cookie_id = u.cookie_id
		AND e.event_time::DATE >= u.start_date 
		LEFT JOIN clique_bait.page_hierarchy ph USING (page_id)
	) AS joined_tables
	GROUP BY visit_id
) AS tmp
LEFT JOIN clique_bait.campaign_identifier ci ON tmp.visit_start_time >= ci.start_date
AND tmp.visit_start_time <= ci.end_date 
;
