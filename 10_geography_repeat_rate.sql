-- Hypothesis test 4: does customer state predict repeat purchase rate?

WITH first_orders AS (
    SELECT c.customer_unique_id, c.customer_state,
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
    fo.customer_state,
    COUNT(*) AS customers,
    ROUND(100.0 * SUM(CASE WHEN cf.frequency > 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS repeat_rate_pct
FROM first_only fo
JOIN customer_freq cf ON cf.customer_unique_id = fo.customer_unique_id
GROUP BY fo.customer_state
HAVING customers >= 300
ORDER BY repeat_rate_pct DESC;

-- RESULT: WEAK effect. Repeat rate ranges 2.0% (CE) to 4.3% (SP/MT) -- ~2x
-- spread, but even the "best" state is still under 5%. Reinforces the
-- structural conclusion rather than pointing to a fixable regional issue.
--
-- OVERALL CONCLUSION (4 hypotheses tested): low repeat purchase is a
-- structural, platform-wide characteristic -- not isolated to a specific
-- segment, category, region, or fixable service failure. See
-- docs/data_cleaning_log.md for the full write-up and reframing into an
-- actionable recommendation.
