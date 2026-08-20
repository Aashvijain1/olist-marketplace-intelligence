-- Executive KPI summary: revenue, orders, customers, AOV, freight
-- Revenue = product price only (excludes freight, tracked separately).
-- Scope: delivered orders only, 2017-01 through 2018-08 (see data_cleaning_log.md
-- for why the edge months are excluded and why customer_unique_id is used).

SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS total_customers,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value,
    ROUND(SUM(oi.freight_value), 2) AS total_freight
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp < '2018-09-01';

-- Result: 96,211 orders | 93,104 customers | R$13,181,027.13 revenue
--         R$137.00 AOV | R$2,192,092.88 freight (~16.6% of revenue)
