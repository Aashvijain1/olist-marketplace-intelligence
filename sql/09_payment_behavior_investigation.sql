-- Hypothesis test 3: does payment behavior (installments, order value)
-- differ between one-time and repeat customers?

WITH first_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
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
    ROUND(AVG(pay.payment_installments), 2) AS avg_installments,
    ROUND(AVG(pay.payment_value), 2) AS avg_payment_value
FROM first_only fo
JOIN customer_freq cf ON cf.customer_unique_id = fo.customer_unique_id
JOIN order_payments pay ON pay.order_id = fo.order_id
GROUP BY customer_type;

-- RESULT: WEAK effect. Repeat customers spend slightly LESS per order
-- (R$134 vs R$151) and use marginally more installments (3.24 vs 2.88) --
-- consistent with repeat customers skewing toward smaller, routine
-- purchases rather than one-off big-ticket items. Not decisive alone, but
-- the strongest signal of the four hypotheses tested (confirmed later by
-- feature importance in the churn model -- payment_value is the top
-- predictor at 32%).
