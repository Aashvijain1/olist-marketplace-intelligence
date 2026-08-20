# Issues Encountered & How They Were Resolved

A real analytics project doesn't run cleanly end-to-end on the first try —
this log documents the actual bugs hit while building this project, why
they happened, and how each was diagnosed and fixed. Included deliberately
rather than hidden, because working through problems like these is a
genuine and representative part of the analyst/BI workflow.

---

## 1. SQLite performance collapse when hosted on Google Drive

**Symptom:** A multi-table join query (customers → orders → order_items →
products → payments → reviews) that should take seconds ran for 10+ minutes
without completing, even after adding indexes.

**Root cause:** The SQLite database file was created inside a Google
Drive–mounted Colab path (`/content/drive/MyDrive/...`). Drive's Colab
mount is a network filesystem — fine for saving a text file, but SQLite
needs frequent small, low-latency read/write operations (especially while
building indexes), which a network mount can't provide.

**Fix:** Moved the database to local Colab disk (`sqlite3.connect("olist.db")`
with no path prefix) and kept Drive mounted only for saving finished
artifacts (`.sql`, `.md`, `.csv` outputs), not for the working database
itself. Index creation on the full 9-table, ~1.3M-row dataset then
completed in under 5 seconds.

**Lesson:** separate *working storage* (fast, local, ephemeral) from
*persistent storage* (slower, durable, for final outputs) — conflating the
two is a common and costly mistake in notebook environments.

---

## 2. `customer_id` vs. `customer_unique_id`

**Symptom:** Early KPI queries showed `total_orders` and `total_customers`
as exactly equal (96,211 = 96,211) — statistically implausible for a
19-month dataset with any repeat buyers at all.

**Root cause:** Olist's `customer_id` field is unique **per order**, not
per person — a returning customer gets a new `customer_id` on every order.
The actual person-level identifier, `customer_unique_id`, is a separate
column.

**Fix:** Every customer-level query (RFM, retention, segmentation, churn
modeling) explicitly joins through and counts `customer_unique_id`, never
`customer_id`. This surfaced the real number: 93,104 unique customers
across 96,211 orders.

**Lesson:** verify what a "unique identifier" column actually guarantees
before relying on it — an ID being unique within one table doesn't mean
it's unique at the grain you actually need.

---

## 3. Power BI: locale-ambiguous date filtering silently halved the dataset

**Symptom:** After applying a date-range filter in Power Query's UI
(typing `1/1/2017` to `9/1/2018`), the orders table dropped from ~96,000
rows to ~45,000 — roughly half of the expected count.

**Root cause:** Power Query's date-filter text boxes interpreted the typed
dates using an ambiguous locale format, likely reading `9/1/2018` as
day-9/month-1 (9 January) instead of the intended September 1 — silently
shrinking the effective date range from ~20 months to ~12.

**Fix:** Rebuilt the filter using Power Query's calendar date-picker
(clicking an actual date) rather than typing text, which removes any
locale ambiguity. Verified against a debug measure (`COUNTROWS`) before
and after to confirm the row count matched the SQL-side baseline exactly
(96,211).

**Lesson:** typed dates are a common, easy-to-miss source of silent data
loss — cross-check row counts against an independent source (in this case,
the original SQL result) rather than assuming a filter did what it looked
like it did.

---

## 4. Power BI measures not respecting the delivered-orders filter

**Symptom:** `Total Revenue` matched the SQL baseline (R$13.18M) on the KPI
card, but the "Revenue by State" bar chart showed the *same* total value
repeated identically across every state — clearly wrong, since states
obviously have different revenue.

**Root cause:** The `Total Revenue` measure used a plain `SUM()` over
`order_items[price]`. Because `order_items` has no direct `order_status` or
date column of its own, a simple SUM ignored the delivered/date filtering
that lived on the `orders` table — the relationship wasn't being enforced
inside the aggregation itself.

**Fix:** Rewrote the measure to explicitly filter through the relationship:
```DAX
Total Revenue =
CALCULATE(
    SUM(clean_order_items[price]),
    FILTER(clean_orders, clean_orders[order_status] = "delivered")
)
```
This one fix corrected every visual referencing the measure simultaneously
(cards, trend line, state chart, category chart) — confirming the problem
was in the measure definition, not the individual visuals.

**Lesson:** a measure that matches an expected total in isolation can still
be structurally wrong — test it broken down by at least one dimension
(state, category, month) before trusting it, not just as a single grand
total.

---

## 5. Line chart showing "(Blank)" and a broken trend shape

**Symptom:** The monthly revenue trend line initially rendered as a single
steep diagonal from a "(Blank)" category to one real month — clearly not a
19-month trend.

**Root cause:** `DimDate[Date]` stored midnight-only dates, while
`clean_orders[order_purchase_timestamp]` included a time-of-day component
(e.g. `2017-01-15 14:23:07`). Power BI relationships require exact value
matches, so almost no rows in `orders` actually linked to `DimDate` at all.

**Fix:** Added a `Date Only` transformation in Power Query to strip the
time component into a new column (`order_date_only`), then rebuilt the
relationship as `DimDate[Date] ↔ clean_orders[order_date_only]`.

**Lesson:** relationships between a date dimension and a timestamp fact
column need matching *grain*, not just matching *type* — Date/Time and
Date look similar but won't join correctly if one carries a time component.

---

## 6. Chronological sort order broken on month labels

**Symptom:** Once the trend line showed real data, the X-axis displayed
months out of order (`2017-11, 2018-05, 2018-04, 2018-01...`).

**Root cause:** The `YearMonth` text column (`"2017-01"`, `"2017-02"`...)
was being sorted alphabetically by default rather than chronologically —
which happens to look right for same-century, same-digit-count strings in
some cases, but isn't guaranteed and broke here.

**Fix:** Added a numeric helper column `YearMonthSort = YEAR(Date)*100 +
MONTH(Date)`, then used **Sort by Column** to sort `YearMonth` by this
numeric field instead of its own text value.

**Lesson:** never rely on the default sort order of a formatted text label —
give any custom-formatted display column an explicit numeric sort key.

---

## 7. XGBoost dtype error from a leftover text column

**Symptom:** `XGBClassifier.fit()` raised
`ValueError: DataFrame.dtypes for data must be int, float, bool or
category... Invalid columns: purchase_weekday: object`.

**Root cause:** `purchase_weekday` was derived in SQL via
`strftime('%w', ...)`, which returns a text string (`'0'`–`'6'`), not a
number. scikit-learn's Random Forest and Gradient Boosting silently
tolerated this via implicit casting; XGBoost enforces strict dtype
checking and refused.

**Fix:** Explicitly cast the column before feature encoding:
`df['purchase_weekday'] = df['purchase_weekday'].astype(int)`.

**Lesson:** don't rely on one library's tolerance for messy types as
implicit validation — a stricter library surfacing an error is doing you a
favor, not being unreasonably picky.

---

## 8. Inconsistent cross-validation fold counts produced a misleading comparison

**Symptom:** A `GridSearchCV` hyperparameter search (`cv=3`) returned a best
ROC-AUC of 0.617 for Gradient Boosting — apparently *worse* than the
untuned model's original cross-validated score of 0.634 (from `cv=5`).

**Root cause:** Scores from different fold counts aren't directly
comparable, especially with a severely imbalanced target (~4.4% positive
class) where fold composition materially affects the estimate. This wasn't
a real regression, just an artifact of comparing two different evaluation
setups.

**Fix:** Did not chase or "fix" this number — recognized it as a
methodology mismatch, kept the original `cv=5` result (0.634) as the
reported baseline, and noted the discrepancy explicitly rather than
silently picking whichever number looked better.

**Lesson:** cross-validation results are only comparable when the
validation setup (fold count, splitting strategy) is held constant —
changing it changes what's being measured, not just how precisely.

---

## Summary

None of these were "the model didn't work" problems — they were data
plumbing, relationship, locale, and dtype issues, which is a realistic
reflection of where time actually goes in applied analytics work. Each was
diagnosed with a specific, falsifiable test (a debug measure, a row count
check, a dtype print) rather than guessed-and-checked, and each fix was
verified against an independent baseline (usually the SQL-side numbers)
before moving on.
