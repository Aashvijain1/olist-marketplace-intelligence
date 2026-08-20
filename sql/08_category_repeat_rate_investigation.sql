-- Hypothesis test 2: does the product category of a customer's first
-- purchase predict repeat rate? (e.g. durable goods like furniture vs.
-- consumables like beauty products)

WITH first_orders AS (
    SELECT
        c.customer_unique_id,
        oi.product_id,
        ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                            ORDER BY o.order_purchase_timestamp) AS rn
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
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
    t.product_category_name_english AS category,
    SUM(CASE WHEN cf.frequency = 1 THEN 1 ELSE 0 END) AS one_time,
    SUM(CASE WHEN cf.frequency > 1 THEN 1 ELSE 0 END) AS repeat,
    ROUND(100.0 * SUM(CASE WHEN cf.frequency > 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS repeat_rate_pct,
    COUNT(*) AS total_first_time_buyers
FROM first_only fo
JOIN products p ON p.product_id = fo.product_id
JOIN category_translation t ON t.product_category_name = p.product_category_name
JOIN customer_freq cf ON cf.customer_unique_id = fo.customer_unique_id
GROUP BY category
HAVING total_first_time_buyers >= 200
ORDER BY repeat_rate_pct DESC;

-- RESULT: NO clear pattern. Repeat rate compressed into a narrow 2.0%-9.1%
-- band across every major category. Durable goods (furniture, appliances)
-- did NOT show lower repeat rates than consumables, contrary to hypothesis.
-- Hypothesis ruled out.
