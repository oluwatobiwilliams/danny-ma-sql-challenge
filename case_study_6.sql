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

How many users are there?
How many cookies does each user have on average?
What is the unique number of visits by all users per month?
What is the number of events for each event type?
What is the percentage of visits which have a purchase event?
What is the percentage of visits which view the checkout page but do not have a purchase event?
What are the top 3 pages by number of views?
What is the number of views and cart adds for each product category?
What are the top 3 products by purchases?
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
