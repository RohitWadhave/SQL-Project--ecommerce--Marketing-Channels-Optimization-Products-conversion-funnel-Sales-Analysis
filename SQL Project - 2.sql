USE mavenfuzzyfactory;

-- Q1.
# ANALYZING CHANNEL PORTFOLIOS
SELECT
	-- YEARWEEK(created_at)
	MIN(DATE(created_at)) AS week_start_date,
    -- COUNT(DISTINCT website_session_id) AS total_sessions,
	COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN website_session_id ELSE NULL END) AS gsearch_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN website_session_id ELSE NULL END) AS bsearch_sessions,
    COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' THEN website_session_id ELSE NULL END)/
      COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' THEN website_session_id ELSE NULL END) AS bsearch_to_gsearch_pct
    
FROM website_sessions

WHERE created_at > '2012-08-22'   -- specified in the request
	AND created_at < '2012-11-29'  -- indicated by the time of the request
	AND utm_campaign = 'nonbrand' -- limiting to nonbrand paid search
    
GROUP BY
	YEARWEEK(created_at)
;
    
    
###################################################################################################################

-- Q2.
# CROSS CHANNEL BID OPTIMIZATION
SELECT
	website_sessions.device_type,
    website_sessions.utm_source,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT order_id) / COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate
    
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
        
WHERE website_sessions.created_at > '2012-08-22'   -- specified in the request
	AND website_sessions.created_at < '2012-09-19'  -- indicated by the time of the request 
	AND website_sessions.utm_campaign = 'nonbrand' -- limiting to nonbrand paid search
    
GROUP BY 
	website_sessions.device_type,
    website_sessions.utm_source
;


###################################################################################################################

-- Q3.
# ANALYZING BUSINESS PATTERNS
SELECT
	hr,
    ROUND(AVG(website_sessions),1) AS avg_sessions,
    ROUND(AVG(CASE WHEN wkday = 0 THEN website_sessions ELSE NULL END),1) AS mon,
    ROUND(AVG(CASE WHEN wkday = 1 THEN website_sessions ELSE NULL END),1) AS tue,
    ROUND(AVG(CASE WHEN wkday = 2 THEN website_sessions ELSE NULL END),1) AS wed,
    ROUND(AVG(CASE WHEN wkday = 3 THEN website_sessions ELSE NULL END),1) AS thu,
    ROUND(AVG(CASE WHEN wkday = 4 THEN website_sessions ELSE NULL END),1) AS fri,
    ROUND(AVG(CASE WHEN wkday = 5 THEN website_sessions ELSE NULL END),1) AS sat,
    ROUND(AVG(CASE WHEN wkday = 6 THEN website_sessions ELSE NULL END),1) AS sun
    
FROM
     (
	  SELECT
		  DATE(created_at) AS created_date,
		  WEEKDAY(created_at) AS wkday,
		  HOUR(created_at) AS hr,
		  COUNT(DISTINCT website_session_id) AS website_sessions
          
	  FROM website_sessions
      
	  WHERE created_at BETWEEN '2013-09-15' AND '2013-11-15'  -- before holiday surge
	  GROUP BY 1,2,3
     ) 
AS daily_hourly_sessions
GROUP BY 
  hr
ORDER BY 
  hr
;


###################################################################################################################

-- Q4.
# PRODUCT PATHING ANALYSIS
#STEP 1: finding the /products pageviews

CREATE TEMPORARY TABLE products_pageviews
SELECT
	website_session_id,
    website_pageview_id,
    created_at,
    CASE
		WHEN created_at < '2013-01-06' THEN 'A. Pre_Product_2'
        WHEN created_at >= '2013-01-06' THEN 'B. Post_Product_2'
        ELSE 'uh oh...check logic'
	END AS time_period
    
FROM website_pageviews

WHERE created_at BETWEEN '2012-10-06' AND '2013-04-06'
	AND pageview_url = '/products'
;
------------------------------------------------------------------------------------------------------------------
#STEP 2: find next pageview id that occurs after product pageview

CREATE TEMPORARY TABLE sessions_w_next_pageview_id
SELECT
	products_pageviews.time_period,
    products_pageviews.website_session_id,
    MIN(website_pageviews.website_pageview_id) AS min_next_pageview_id
    
FROM products_pageviews
	LEFT JOIN website_pageviews
		ON website_pageviews.website_session_id = products_pageviews.website_session_id
			AND website_pageviews.website_pageview_id > products_pageviews.website_pageview_id
            
GROUP BY 1,2
;
------------------------------------------------------------------------------------------------------------------
#STEP 3: find pageview_url associated with any applicable next pageview id

CREATE TEMPORARY TABLE sessions_w_next_pageview_url
SELECT
    sessions_w_next_pageview_id.time_period,
    sessions_w_next_pageview_id.website_session_id,
    website_pageviews.pageview_url AS next_pageview_url
    
FROM sessions_w_next_pageview_id
	LEFT JOIN website_pageviews
		ON sessions_w_next_pageview_id.min_next_pageview_id = website_pageviews.website_pageview_id
;
------------------------------------------------------------------------------------------------------------------
#STEP 4: summarize the data and analyze pre and post periods

SELECT
	time_period,
    COUNT(DISTINCT website_session_id) AS sessions,
    
    COUNT(DISTINCT CASE WHEN next_pageview_url  IS NOT NULL THEN website_session_id ELSE NULL END) AS w_next_pg,
    COUNT(DISTINCT CASE WHEN next_pageview_url  IS NOT NULL THEN website_session_id ELSE NULL END) /
		COUNT(DISTINCT website_session_id) AS pct_w_next_pg,
        
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END) AS to_mr_fuzzy,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-original-mr-fuzzy' THEN website_session_id ELSE NULL END) /
		COUNT(DISTINCT website_session_id) AS pct_to_mrfuzzy,
        
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id ELSE NULL END) AS to_lovebear,
    COUNT(DISTINCT CASE WHEN next_pageview_url = '/the-forever-love-bear' THEN website_session_id ELSE NULL END) /
        COUNT(DISTINCT website_session_id) AS pct_to_lovebear
    
FROM sessions_w_next_pageview_url
GROUP BY time_period
;


###################################################################################################################

-- Q5.
# PRODUCT CONVERISON FUNNELS
#STEP 1: select all pageviews for relevant sessions

CREATE TEMPORARY TABLE sessions_seeing_product_pages
SELECT
	website_session_id,
    website_pageview_id,
	pageview_url AS product_page_seen
    
FROM website_pageviews

WHERE created_at BETWEEN '2013-01-06' AND '2013-04-10'
	AND pageview_url IN ('/the-original-mr-fuzzy', '/the-forever-love-bear')
;
------------------------------------------------------------------------------------------------------------------
#STEP 2: figure out which pageview urls to look for

SELECT DISTINCT
	website_pageviews.pageview_url
    
FROM sessions_seeing_product_pages

	LEFT JOIN website_pageviews
		ON sessions_seeing_product_pages.website_session_id = website_pageviews.website_session_id
			AND website_pageviews.website_pageview_id > sessions_seeing_product_pages.website_pageview_id
;
------------------------------------------------------------------------------------------------------------------
#STEP 3: pull all pageviews and identify the funnel steps

SELECT
	sessions_seeing_product_pages.website_session_id,
    sessions_seeing_product_pages.product_page_seen,
	CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
    CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
    CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing_page,
    CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
    
FROM sessions_seeing_product_pages
	LEFT JOIN website_pageviews
		ON sessions_seeing_product_pages.website_session_id = website_pageviews.website_session_id
			AND website_pageviews.website_pageview_id > sessions_seeing_product_pages.website_pageview_id
            
ORDER BY
	sessions_seeing_product_pages.website_session_id,
	website_pageviews.created_at
;
------------------------------------------------------------------------------------------------------------------
#STEP 4: create session level conversion funnel view

CREATE TEMPORARY TABLE session_product_level_made_it_flags
SELECT
	website_session_id,
    CASE
		WHEN product_page_seen = '/the-original-mr-fuzzy' THEN 'mrfuzzy'
		WHEN product_page_seen = '/the-forever-love-bear' THEN 'lovebear'
		ELSE 'uh oh...check logic'
	END AS product_seen,
    SUM(cart_page) AS to_cart,
    SUM(shipping_page) AS to_shipping,
    SUM(billing_page) AS to_billing,
    SUM(thankyou_page) AS to_thankyou
    
FROM   
     (
	  SELECT
		  sessions_seeing_product_pages.website_session_id,
		  sessions_seeing_product_pages.product_page_seen,
		  CASE WHEN pageview_url = '/cart' THEN 1 ELSE 0 END AS cart_page,
		  CASE WHEN pageview_url = '/shipping' THEN 1 ELSE 0 END AS shipping_page,
		  CASE WHEN pageview_url = '/billing-2' THEN 1 ELSE 0 END AS billing_page,
		  CASE WHEN pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END AS thankyou_page
	  FROM sessions_seeing_product_pages
		  LEFT JOIN website_pageviews
			  ON sessions_seeing_product_pages.website_session_id = website_pageviews.website_session_id
				  AND website_pageviews.website_pageview_id > sessions_seeing_product_pages.website_pageview_id
	  ORDER BY
		  sessions_seeing_product_pages.website_session_id,
		  website_pageviews.created_at
     ) 
AS funnel_steps

GROUP BY
	website_session_id,
    product_seen
;
------------------------------------------------------------------------------------------------------------------
#STEP 5: aggregate data to assess funnel performance

SELECT
	product_seen,
    COUNT(website_session_id) AS sessions,
    SUM(to_cart) AS to_cart,
    SUM(to_shipping) AS to_shipping,
    SUM(to_billing) AS to_billing,
    SUM(to_thankyou) AS to_thankyou
    
FROM session_product_level_made_it_flags

GROUP BY 1 
ORDER BY 1 
;
------------------------------------------------------------------------------------------------------------------
#STEP 6: aggregating data in terms of clickthrough rates to assess funnel performance

SELECT
	product_seen,
    SUM(to_cart) /COUNT(website_session_id) AS product_page_click_rt,
    SUM(to_shipping) / SUM(to_cart) AS cart_click_rt,
    SUM(to_billing) / SUM(to_shipping) AS shipping_click_rt,
    SUM(to_thankyou) / SUM(to_billing) AS billing_click_rt
    
FROM session_product_level_made_it_flags

GROUP BY 1
ORDER BY 1 
;


###################################################################################################################

-- Q6.
# CROSS SELL ANALYSIS
#STEP 1: identify the relevant /cart page views and their sessions

CREATE TEMPORARY TABLE sessions_seeing_cart
SELECT
	CASE
		WHEN created_at < '2013-09-25' THEN 'A. Pre_Cross_Sell'
        WHEN created_at >= '2013-09-25' THEN 'B. Post_Cross_Sell'
        ELSE 'uh oh...check logic'
	END AS time_period,
	website_session_id AS cart_session_id,
	website_pageview_id AS cart_pageview_id
    
FROM website_pageviews

WHERE created_at BETWEEN '2013-08-25' AND '2013-10-25'  -- Specified in the request
	AND pageview_url = '/cart'
;
------------------------------------------------------------------------------------------------------------------
#STEP 2: see which of those /cart sessions clicked through the shipping page

CREATE TEMPORARY TABLE cart_sessions_seeing_another_page
SELECT
	sessions_seeing_cart.time_period,
    sessions_seeing_cart.cart_session_id,
    MIN(website_pageviews.website_pageview_id) AS pv_id_after_cart
    
FROM sessions_seeing_cart
	LEFT JOIN website_pageviews
		ON sessions_seeing_cart.cart_session_id = website_pageviews.website_session_id
			AND website_pageviews.website_pageview_id > sessions_seeing_cart.cart_pageview_id
            
GROUP BY 1,2
HAVING 
	MIN(website_pageviews.website_pageview_id) IS NOT NULL
;
------------------------------------------------------------------------------------------------------------------
#STEP 3: find the orders associated with /cart sessions; analyze products purchased, AOV; aggregate

CREATE TEMPORARY TABLE pre_post_sessions_orders
SELECT
	time_period,
    cart_session_id,
    order_id,
    items_purchased,
    price_usd
    
FROM sessions_seeing_cart
	INNER JOIN orders
		ON sessions_seeing_cart.cart_session_id = orders.website_session_id
;
------------------------------------------------------------------------------------------------------------------
# This will be used as Subquery in next step

SELECT
	sessions_seeing_cart.time_period,
	sessions_seeing_cart.cart_session_id,
	CASE WHEN cart_sessions_seeing_another_page.cart_session_id IS NULL THEN 0 ELSE 1 END AS clicked_to_another_page,
	CASE WHEN pre_post_sessions_orders.order_id IS NULL THEN 0 ELSE 1 END AS placed_order,
	pre_post_sessions_orders.items_purchased,
	pre_post_sessions_orders.price_usd
          
FROM sessions_seeing_cart
	LEFT JOIN cart_sessions_seeing_another_page
		ON sessions_seeing_cart.cart_session_id = cart_sessions_seeing_another_page.cart_session_id
	LEFT JOIN pre_post_sessions_orders
		ON sessions_seeing_cart.cart_session_id = pre_post_sessions_orders.cart_session_id
              
ORDER BY
	cart_session_id
;
------------------------------------------------------------------------------------------------------------------
#STEP 4: summarize the data and analyze the pre vs post cross-sell periods

SELECT
	time_period,
    COUNT(DISTINCT cart_session_id) AS cart_sessions,
    SUM(clicked_to_another_page) AS clickthroughs,
    SUM(clicked_to_another_page) / COUNT(DISTINCT cart_session_id) AS cart_ctr,
    SUM(items_purchased) / SUM(placed_order) AS products_per_order,
    SUM(price_usd) / SUM(placed_order) AS aov, #average order value
    SUM(price_usd) / COUNT(DISTINCT cart_session_id) AS rev_per_cart_session
    
FROM
     (
	  SELECT
		  sessions_seeing_cart.time_period,
		  sessions_seeing_cart.cart_session_id,
		  CASE WHEN cart_sessions_seeing_another_page.cart_session_id IS NULL THEN 0 ELSE 1 END AS clicked_to_another_page,
		  CASE WHEN pre_post_sessions_orders.order_id IS NULL THEN 0 ELSE 1 END AS placed_order,
		  pre_post_sessions_orders.items_purchased,
		  pre_post_sessions_orders.price_usd
          
	  FROM sessions_seeing_cart
		  LEFT JOIN cart_sessions_seeing_another_page
			  ON sessions_seeing_cart.cart_session_id = cart_sessions_seeing_another_page.cart_session_id
		  LEFT JOIN pre_post_sessions_orders
			  ON sessions_seeing_cart.cart_session_id = pre_post_sessions_orders.cart_session_id
              
	  ORDER BY
		  cart_session_id
    ) 
AS data_list

GROUP BY
	time_period
;


###################################################################################################################
-- Q7.
# PRODUCT REFUND RATES

SELECT
	YEAR(order_items.created_at) AS yr,
    MONTH(order_items.created_at) AS mo,
    COUNT(DISTINCT CASE WHEN order_items.product_id = 1 THEN order_items.order_item_id ELSE NULL END) AS p1_orders,
    #COUNT(DISTINCT CASE WHEN (order_items.product_id = 1 AND order_item_refunds.order_item_id IS NOT NULL) THEN order_item_refunds.order_id ELSE NULL END) AS p1_refund,
    COUNT(DISTINCT CASE WHEN (order_items.product_id = 1 AND order_item_refunds.order_item_id IS NOT NULL) THEN order_item_refunds.order_id ELSE NULL END) /
		COUNT(DISTINCT CASE WHEN order_items.product_id = 1 THEN order_items.order_item_id ELSE NULL END) AS p1_refund_rt,
	
    COUNT(DISTINCT CASE WHEN order_items.product_id = 2 THEN order_items.order_item_id ELSE NULL END) AS p2_orders,
    #COUNT(DISTINCT CASE WHEN (order_items.product_id = 2 AND order_item_refunds.order_item_id IS NOT NULL) THEN order_item_refunds.order_id ELSE NULL END) AS p2_refund,
    COUNT(DISTINCT CASE WHEN (order_items.product_id = 2 AND order_item_refunds.order_item_id IS NOT NULL) THEN order_item_refunds.order_id ELSE NULL END) /
		COUNT(DISTINCT CASE WHEN order_items.product_id = 2 THEN order_items.order_item_id ELSE NULL END) AS p2_refund_rt,
	
    COUNT(DISTINCT CASE WHEN order_items.product_id = 3 THEN order_items.order_item_id ELSE NULL END) AS p3_orders,
    #COUNT(DISTINCT CASE WHEN (order_items.product_id = 3 AND order_item_refunds.order_item_id IS NOT NULL) THEN order_item_refunds.order_id ELSE NULL END) AS p3_refund,
    COUNT(DISTINCT CASE WHEN (order_items.product_id = 3 AND order_item_refunds.order_item_id IS NOT NULL) THEN order_item_refunds.order_id ELSE NULL END) /
		COUNT(DISTINCT CASE WHEN order_items.product_id = 3 THEN order_items.order_item_id ELSE NULL END) AS p3_refund_rt,
	
    COUNT(DISTINCT CASE WHEN order_items.product_id = 4 THEN order_items.order_item_id ELSE NULL END) AS p4_orders,
    #COUNT(DISTINCT CASE WHEN (order_items.product_id = 4 AND order_item_refunds.order_item_id IS NOT NULL) THEN order_item_refunds.order_id ELSE NULL END) AS p4_refund,
    COUNT(DISTINCT CASE WHEN (order_items.product_id = 4 AND order_item_refunds.order_item_id IS NOT NULL) THEN order_item_refunds.order_id ELSE NULL END) /
		COUNT(DISTINCT CASE WHEN order_items.product_id = 4 THEN order_items.order_item_id ELSE NULL END) AS p4_refund_rt
        
        
FROM order_items
	LEFT JOIN order_item_refunds
		ON order_items.order_item_id = order_item_refunds.order_item_id
        
WHERE order_items.created_at < '2014-10-15'
GROUP BY 1,2
;


###################################################################################################################

-- Q8.
# IDENTIFYING REPEAT VISITORS  
# This will be used as Subquery in next step

SELECT
	user_id,
	is_repeat_session,
	SUM(is_repeat_session) AS repeat_sessions
          
FROM website_sessions
WHERE created_at BETWEEN '2014-01-01' AND '2014-11-01'
      
GROUP BY 1
ORDER BY 1 
;      
------------------------------------------------------------------------------------------------------------------      
SELECT
	repeat_sessions,
    COUNT(user_id) AS users
FROM
     (
	  SELECT
		  user_id,
          is_repeat_session,
		  SUM(is_repeat_session) AS repeat_sessions
          
	  FROM website_sessions
	  WHERE created_at BETWEEN '2014-01-01' AND '2014-11-01'
      
	  GROUP BY 1
      ORDER BY 1 
     ) 
AS sessions_number

WHERE is_repeat_session = 0
GROUP BY 1
ORDER BY 1
;


###################################################################################################################

-- Q9.
# NEW VS REPEAT CHANNEL PATTERNS

SELECT DISTINCT
	utm_source,
    utm_campaign,
    http_referer
    
FROM website_sessions

WHERE created_at BETWEEN '2014-01-01' AND '2014-11-05'
GROUP BY 1,2,3
;
------------------------------------------------------------------------------------------------------------------
SELECT
	CASE
		WHEN utm_source IS NULL AND http_referer IS NULL THEN 'direct_type_in'
        WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN 'organic_search'
        WHEN utm_campaign = 'brand' AND http_referer IS NOT NULL THEN 'paid_brand'
        WHEN utm_campaign = 'nonbrand' AND http_referer IS NOT NULL THEN 'paid_nonbrand'
        WHEN utm_source = 'socialbook' AND http_referer IS NOT NULL THEN 'paid_social'
        ELSE 'uh oh...check logic'
	END AS channel_group,
    
    COUNT(CASE WHEN is_repeat_session = 0 THEN website_session_id ELSE NULL END) AS new_sessions,
    COUNT(CASE WHEN is_repeat_session = 1 THEN website_session_id ELSE NULL END) AS repeat_sessions
    
FROM website_sessions
WHERE created_at BETWEEN '2014-01-01' AND '2014-11-05'

GROUP BY 1
ORDER BY 
   repeat_sessions DESC
;


###################################################################################################################

-- Q10.
# NEW VS REPEAT PERFORMANCE

SELECT
	website_sessions.is_repeat_session,
    COUNT(DISTINCT website_sessions.website_session_id) AS sessions,
    #COUNT(DISTINCT orders.order_id) AS orders,
    COUNT(DISTINCT orders.order_id) / COUNT(DISTINCT website_sessions.website_session_id) AS conv_rate,
    SUM(price_usd) / COUNT(DISTINCT website_sessions.website_session_id) AS rev_per_session
    
FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
        
WHERE website_sessions.created_at BETWEEN '2014-01-01' AND '2014-11-08'
GROUP BY 1
;


###################################################################################################################

-- Q11.
SELECT
	YEAR(website_sessions.created_at) AS yr,
	QUARTER(website_sessions.created_at) AS qtr,
	COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT website_sessions.website_session_id) AS session_to_order_conv_rate,
	SUM(price_usd)/COUNT(DISTINCT orders.order_id) AS revenue_per_order,
	SUM(price_usd)/COUNT(DISTINCT website_sessions.website_session_id) AS revenue_per_session

FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id
        
GROUP BY 1,2
ORDER BY 1,2
;


###################################################################################################################

-- Q12.
SELECT
	YEAR(website_sessions.created_at) AS yr, 
	QUARTER(website_sessions.created_at) AS qtr,
	COUNT(DISTINCT CASE WHEN utm_source= 'gsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END) AS gsearch_nonbrand_orders, 
	COUNT(DISTINCT CASE WHEN utm_source= 'bsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END) AS bsearch_nonbrand_orders, 
	COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN orders.order_id ELSE NULL END) AS brand_search_orders,
	COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN orders.order_id ELSE NULL END) AS organic_search_orders, 
	COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN orders.order_id ELSE NULL END) AS direct_type_in_orders

FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id

GROUP BY 1,2
ORDER BY 1,2
;


###################################################################################################################

-- Q13.
SELECT
YEAR(website_sessions.created_at) AS yr,
QUARTER(website_sessions.created_at) AS qtr,

COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END)
	/COUNT(DISTINCT CASE WHEN utm_source = 'gsearch' AND utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) 
AS gsearch_nonbrand_conv_rt,

COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN orders.order_id ELSE NULL END)
	/COUNT(DISTINCT CASE WHEN utm_source = 'bsearch' AND utm_campaign = 'nonbrand' THEN website_sessions.website_session_id ELSE NULL END) 
AS bsearch_nonbrand_conv_rt,

COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN orders.order_id ELSE NULL END)
	/COUNT(DISTINCT CASE WHEN utm_campaign = 'brand' THEN website_sessions.website_session_id ELSE NULL END) 
AS brand_search_conv_rt,

COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN orders.order_id ELSE NULL END)
	/COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NOT NULL THEN website_sessions.website_session_id ELSE NULL END) 
AS organic_search_conv_rt,

COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN orders.order_id ELSE NULL END)
	/COUNT(DISTINCT CASE WHEN utm_source IS NULL AND http_referer IS NULL THEN website_sessions.website_session_id ELSE NULL END)
AS direct_type_in_conv_rt

FROM website_sessions
	LEFT JOIN orders
		ON website_sessions.website_session_id = orders.website_session_id

GROUP BY 1,2
ORDER BY 1,2
;


###################################################################################################################

-- Q14.
-- first, identifying all the views of the /products page 

CREATE TEMPORARY TABLE products_pageviews
SELECT
	website_session_id,
	website_pageview_id,
	created_at AS saw_product_page_at
    
FROM website_pageviews
WHERE pageview_url = '/products'
;
------------------------------------------------------------------------------------------------------------------
SELECT
YEAR(saw_product_page_at) AS yr,
MONTH(saw_product_page_at) AS mo,
COUNT(DISTINCT products_pageviews.website_session_id) AS sessions_to_product_page,
COUNT(DISTINCT website_pageviews.website_session_id) AS clicked_to_next_page,
COUNT(DISTINCT website_pageviews.website_session_id)/COUNT(DISTINCT products_pageviews.website_session_id) AS clickthrough_rt, COUNT(DISTINCT orders.order_id) AS orders,
COUNT(DISTINCT orders.order_id)/COUNT(DISTINCT products_pageviews.website_session_id) AS products_to_order_rt

FROM products_pageviews
LEFT JOIN website_pageviews
ON website_pageviews.website_session_id = products_pageviews.website_session_id -- same session
AND website_pageviews.website_pageview_id> products_pageviews.website_pageview_id  -- they had another page AFTER
LEFT JOIN orders
ON orders.website_session_id = products_pageviews.website_session_id

GROUP BY 1,2
;


###################################################################################################################

-- Q15.
CREATE TEMPORARY TABLE primary_products
SELECT
	order_id,
	primary_product_id,
	created_at AS ordered_at

FROM orders
WHERE created_at > '2014-12-05' -- when the 4th product was added (says so in question)
;
------------------------------------------------------------------------------------------------------------------
-- This will be used as sub-query in next step

SELECT
	primary_products.*,
	order_items.product_id AS cross_sell_product_id

FROM primary_products
	LEFT JOIN order_items
		ON order_items.order_id = primary_products.order_id 
		AND order_items.is_primary_item = 0     -- only bringing in cross-sells
;
------------------------------------------------------------------------------------------------------------------
SELECT
	primary_product_id,
	COUNT(DISTINCT order_id) AS total_orders,
	COUNT(DISTINCT CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END) AS _xsold_p1,
	COUNT(DISTINCT CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END) AS _xsold_p2,
	COUNT(DISTINCT CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END) AS _xsold_p3,
	COUNT(DISTINCT CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END) AS _xsold_p4,
	COUNT(DISTINCT CASE WHEN cross_sell_product_id = 1 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p1_xsell_rt,
	COUNT(DISTINCT CASE WHEN cross_sell_product_id = 2 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p2_xsell_rt,
	COUNT(DISTINCT CASE WHEN cross_sell_product_id = 3 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p3_xsell_rt,
	COUNT(DISTINCT CASE WHEN cross_sell_product_id = 4 THEN order_id ELSE NULL END)/COUNT(DISTINCT order_id) AS p4_xsell_rt

FROM
	 (
	  SELECT
		  primary_products.*,
		  order_items.product_id AS cross_sell_product_id
        
	  FROM primary_products
		  LEFT JOIN order_items
			  ON order_items.order_id = primary_products.order_id
			  AND order_items.is_primary_item = 0  -- only bringing in cross-sells
	 )
AS primary_w_cross_sell

GROUP BY 1
;