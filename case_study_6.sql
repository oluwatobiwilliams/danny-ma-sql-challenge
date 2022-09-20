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