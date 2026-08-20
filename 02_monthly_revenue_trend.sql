-- Monthly revenue trend + month-over-month growth %
-- Demonstrates: date bucketing (strftime), window function (LAG) for
-- period-over-period comparison.

WITH monthly AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS order_month,
        SUM(oi.price) AS revenue,
        COUNT(DISTINCT o.order_id) AS orders
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY order_month
)
SELECT
    order_month,
    ROUND(revenue, 2) AS revenue,
    orders,
    ROUND(revenue - LAG(revenue) OVER (ORDER BY order_month), 2) AS mom_change,
    ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY order_month))
          / LAG(revenue) OVER (ORDER BY order_month), 1) AS mom_growth_pct
FROM monthly
ORDER BY order_month;

-- Finding: steady growth through 2017 (peaking +52% MoM in Nov 2017, likely
-- Black Friday), but growth stalled in 2018 -- May 2018 (R$977K) was the
-- effective peak; Jun-Aug 2018 stayed flat/below it. Deceleration, not decline.
