-- Hypothesis test 1: does delivery experience predict repeat purchase?
-- Scope controls for reorder-eligibility: only customers whose FIRST order
-- was before 2018-03-01, giving everyone 6+ months to reorder before the
-- 2018-09-01 data cutoff -- otherwise recent customers would be unfairly
-- counted as "one-time" just for lack of time.

WITH first_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date,
        ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                            ORDER BY o.order_purchase_timestamp) AS rn
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-03-01'
),
first_only AS (SELECT * FROM first_orders WHERE rn = 1),
customer_freq AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS frequency
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY c.customer_unique_id
)
SELECT
    CASE WHEN cf.frequency = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
    COUNT(*) AS customers,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    ROUND(AVG(JULIANDAY(fo.order_delivered_customer_date) - JULIANDAY(fo.order_purchase_timestamp)), 1) AS avg_delivery_days,
    ROUND(AVG(JULIANDAY(fo.order_delivered_customer_date) - JULIANDAY(fo.order_estimated_delivery_date)), 1) AS avg_days_early_or_late
FROM first_only fo
JOIN customer_freq cf ON cf.customer_unique_id = fo.customer_unique_id
LEFT JOIN order_reviews r ON r.order_id = fo.order_id
GROUP BY customer_type;

-- RESULT: NO effect. One-time (4.13) vs repeat (4.19) review scores nearly
-- identical; both delivered ~13 days, both ~11-12 days early vs estimate.
-- Hypothesis ruled out.
