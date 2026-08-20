-- Confirms the exact scale of the one-time-purchase pattern found in
-- 05_rfm_base.sql.

WITH customer_orders AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS frequency
    FROM orders o
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY c.customer_unique_id
)
SELECT
    SUM(CASE WHEN frequency = 1 THEN 1 ELSE 0 END) AS one_time_customers,
    SUM(CASE WHEN frequency > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN frequency = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_one_time
FROM customer_orders;

-- Result: 90,315 one-time (97.0%) vs 2,789 repeat customers.
-- This became the project's central question: WHY is repeat purchase so
-- rare, and can it be explained by any single factor? (see queries 07-10)
