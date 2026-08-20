# Data Cleaning & Investigation Log
Customer & Sales Intelligence Platform — Olist Brazilian E-Commerce Dataset

## Data Cleaning Decisions
- 99,441 total orders. Status breakdown: 96,478 delivered (97%), 625 canceled,
  609 unavailable, 1,107 shipped, 314 invoiced, 301 processing, 5 created, 2 approved.
- Revenue calculations use `order_status = 'delivered'` only — canceled/unavailable
  orders never generated real revenue.
- No duplicate `order_id` values found in the orders table.
- 2,965 orders missing `order_delivered_customer_date` — consistent with
  non-delivered statuses, not a data error.
- `customer_id` is unique per ORDER, not per person. Used `customer_unique_id`
  throughout for any customer-level counting (total customers, repeat purchase,
  RFM, etc.) to avoid inflating customer counts (96,211 orders vs. 93,104
  actual unique customers).
- Usable date range: 2017-01 to 2018-08. Excluded 2016-09 to 2016-12 (329
  orders) and 2018-09/2018-10 (20 orders) as partial-month artifacts of the
  data collection window, not real business signal.
- Revenue = product price only (`order_items.price`). Freight tracked as a
  separate metric (~17% of product revenue) rather than folded into "revenue,"
  since freight is a pass-through shipping cost, not a reflection of sales
  performance.

## Key Findings

### 1. Growth trend
Revenue grew steadily through 2017 (peaking +52% MoM in Nov 2017, likely
Black Friday), but growth stalled in 2018 — May 2018 (R$977K) was the
effective peak; Jun–Aug 2018 stayed flat/below it. Deceleration, not decline.

### 2. Geographic concentration
São Paulo (SP) = 42% of customers, 38% of revenue — more than the next 5
states combined. But SP has one of the LOWEST average order values (R$125),
while small/remote states (PB, AP, AC) have the highest AOV (~R$200+).
Remote customers order less often but spend more per order.

### 3. Category performance
No single product category dominates revenue (top category `health_beauty`
is only ~9% of total) — concentration risk is geographic, not product-based.
`watches_gifts` has the highest AOV (R$212); `telephony` has high order
volume but the lowest AOV (R$76), suggesting cheap accessories rather than
phones themselves.

### 4. Repeat purchase investigation (central finding)
**97% of customers are one-time buyers** (90,315 of 93,104). Tested four
hypotheses for the cause, controlling for reorder-eligibility (first order
before March 2018, giving 6+ months to reorder before the data cutoff):

| Hypothesis | Result |
|---|---|
| Delivery experience (review score, delivery speed, on-time %) | **No effect.** One-time (4.13) vs. repeat (4.19) review scores nearly identical; both delivered in ~13 days, both ~11-12 days early vs. estimate. |
| Product category | **No clear pattern.** Repeat rate compressed into a narrow 2.0%–9.1% band across every major category; durable goods did not show lower repeat rates than consumables as hypothesized. |
| Payment behavior | **Weak effect.** Repeat customers spend slightly less per order (R$134 vs. R$151), use marginally more installments (3.24 vs. 2.88). |
| Geography | **Weak effect.** Repeat rate ranges 2.0% (CE) to 4.3% (SP/MT) — ~2x spread, but even the best state stays under 5%. |

**Conclusion:** low repeat-purchase rate is a structural, platform-wide
characteristic of the business — not isolated to a specific segment,
category, region, or a fixable service failure. This reframes the business
question from "find the broken segment" to "the marketplace model isn't
building repeat relationships on its own — what could change that."

## Model: Repeat-Purchase Prediction

Compared 4 models via 5-fold cross-validated ROC-AUC on 106 features
(category, state, payment behavior, delivery timing, review score):

| Model | ROC-AUC (5-fold CV) |
|---|---|
| Dummy baseline | 0.498 |
| Logistic Regression | 0.614 |
| Random Forest | 0.621 |
| **Gradient Boosting** | **0.634** |

All three real models clearly beat random guessing, but no model reliably
classifies individual customers (best F1 for the repeat class: 0.02–0.11
depending on model/threshold) — consistent with the SQL investigation's
conclusion that repeat purchase has no single strong driver.

**Reframed as a ranking/targeting tool** instead of a hard classifier:
customers in the top 10% by predicted probability have a **9.5% actual
repeat rate vs. a 4.4% baseline — a 2.1x lift**. Not reliable enough to
predict any individual customer's behavior, but genuinely useful for
prioritizing a win-back/loyalty campaign budget toward the customers most
likely to respond.

**Top predictive features:** `payment_value` (32%), `days_early_or_late`
(15%), `delivery_days` (7%), `payment_installments` (7%) — payment behavior
and delivery timing matter more in combination than any showed in isolation
during the SQL investigation. Notably, `review_score` did not rank in the
top 15 features, reinforcing that satisfaction alone doesn't explain repeat
behavior.

Hyperparameter tuning (grid search) and XGBoost were tested as extensions;
neither meaningfully improved on the baseline Gradient Boosting result,
reinforcing that ~0.63 AUC represents a practical ceiling given the
available features.

## RFM Segmentation

Because 75%+ of customers have Frequency = 1, standard 5-way quintile
scoring on Frequency isn't viable. Segmentation instead uses **Recency +
Monetary only**:

| Segment | Customers | Avg Spend | Total Value |
|---|---|---|---|
| Champions | 15,404 | R$270.72 | R$4,170,128.14 |
| High Value At Risk | 14,429 | R$278.51 | R$4,018,607.75 |
| Needs Attention | 26,083 | R$121.11 | R$3,158,956.69 |
| Recent, Lower Spend | 21,915 | R$55.74 | R$1,221,589.10 |
| Lost / Low Value | 15,273 | R$40.05 | R$611,745.45 |

**"High Value At Risk" + "Champions" = R$8.19M — 62% of total revenue**
sitting in customers who are either already gone or at risk of going.
