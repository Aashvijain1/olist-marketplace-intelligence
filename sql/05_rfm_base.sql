-- RFM base table: Recency (days since last order), Frequency (order count),
-- Monetary (total spend) per customer, as of snapshot date 2018-09-01
-- (the day after the usable data range ends).

WITH snapshot AS (SELECT '2018-09-01' AS snapshot_date),
customer_orders AS (
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_order_date,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price) AS monetary
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp < '2018-09-01'
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    CAST(JULIANDAY((SELECT snapshot_date FROM snapshot)) - JULIANDAY(last_order_date) AS INT) AS recency_days,
    frequency,
    ROUND(monetary, 2) AS monetary
FROM customer_orders;

-- Finding: median AND 75th-percentile frequency = 1. At least 75% of
-- customers are one-time buyers -- classic RFM quintile scoring on Frequency
-- isn't viable here (see docs/data_cleaning_log.md). Segmentation instead
-- uses Recency + Monetary only (rfm_segments.csv / 11_rfm_segmentation.py).
