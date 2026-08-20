-- Category performance
SELECT
    t.product_category_name_english AS category,
    ROUND(SUM(oi.price), 2) AS revenue,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p ON p.product_id = oi.product_id
JOIN category_translation t ON t.product_category_name = p.product_category_name
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp < '2018-09-01'
GROUP BY category
ORDER BY revenue DESC
LIMIT 15;

-- Top 3 products per category by revenue, using RANK() PARTITION BY
WITH product_revenue AS (
    SELECT
        t.product_category_name_english AS category,
        oi.product_id,
        ROUND(SUM(oi.price), 2) AS revenue,
        RANK() OVER (PARTITION BY t.product_category_name_english
                      ORDER BY SUM(oi.price) DESC) AS rank_in_category
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    JOIN category_translation t ON t.product_category_name = p.product_category_name
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY category, oi.product_id
)
SELECT * FROM product_revenue
WHERE rank_in_category <= 3
ORDER BY revenue DESC
LIMIT 30;

-- Finding: no single category dominates (top category health_beauty is only
-- ~9% of total) -- revenue concentration risk is geographic (SP), not
-- product-based. watches_gifts has the highest AOV (R$212); telephony has
-- high volume but the lowest AOV (R$76).
