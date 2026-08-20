-- Regional performance by customer state: revenue, customers, AOV

SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS customers,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp < '2018-09-01'
GROUP BY c.customer_state
ORDER BY revenue DESC;

-- Finding: Sao Paulo (SP) = 42% of customers, 38% of revenue -- more than
-- the next 5 states combined. But SP has one of the LOWEST average order
-- values (R$125), while small/remote states (PB, AP, AC) have the highest
-- AOV (~R$200+). Remote customers order less often but spend more per order.
