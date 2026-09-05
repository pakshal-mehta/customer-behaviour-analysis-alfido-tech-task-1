-- =============================================================================
-- Alfido Tech | E-Commerce Customer Analytics — Analysis Queries
-- ANSI SQL, validated against DuckDB. Assumes a table named `transactions`
-- already exists with the cleaned data (columns listed below) — no table
-- creation or data loading here, queries only.
--
-- Expected columns in `transactions`:
--   customer_id, purchase_date, product_category, product_price, quantity,
--   total_purchase_amount, payment_method, customer_age, is_return,
--   customer_name, gender, churn
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. BASIC SUMMARY STATISTICS
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*)                                   AS total_orders,
    COUNT(DISTINCT customer_id)                AS total_customers,
    ROUND(AVG(total_purchase_amount), 2)       AS avg_order_value,
    ROUND(SUM(total_purchase_amount), 2)       AS total_revenue,
    MIN(purchase_date)                         AS first_order_date,
    MAX(purchase_date)                         AS last_order_date
FROM transactions;

-- Data-quality check
SELECT
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END)  AS missing_customer_id,
    SUM(CASE WHEN product_price <= 0 THEN 1 ELSE 0 END)   AS invalid_price,
    SUM(CASE WHEN quantity <= 0 THEN 1 ELSE 0 END)        AS invalid_quantity
FROM transactions;

-- -----------------------------------------------------------------------------
-- 2. REVENUE BY CATEGORY (bar chart source)
-- -----------------------------------------------------------------------------
SELECT
    product_category,
    COUNT(*)                                AS orders,
    ROUND(SUM(total_purchase_amount), 2)    AS revenue
FROM transactions
GROUP BY product_category
ORDER BY revenue DESC;

-- -----------------------------------------------------------------------------
-- 3. MONTHLY REVENUE TREND (line chart source)
-- -----------------------------------------------------------------------------
SELECT
    DATE_TRUNC('month', purchase_date)      AS month,        -- SQL Server: FORMAT(purchase_date,'yyyy-MM')
    ROUND(SUM(total_purchase_amount), 2)    AS revenue,
    COUNT(DISTINCT customer_id)             AS active_customers
FROM transactions
GROUP BY 1
ORDER BY 1;

-- -----------------------------------------------------------------------------
-- 4. RFM BASE TABLE (per customer)
-- -----------------------------------------------------------------------------
WITH snapshot AS (
    SELECT MAX(purchase_date) + INTERVAL '1 day' AS snapshot_date FROM transactions
)
SELECT
    t.customer_id,
    DATE_PART('day', s.snapshot_date - MAX(t.purchase_date))  AS recency_days,
    COUNT(*)                                                    AS frequency,
    ROUND(SUM(t.total_purchase_amount), 2)                      AS monetary
FROM transactions t
CROSS JOIN snapshot s
GROUP BY t.customer_id, s.snapshot_date;

-- -----------------------------------------------------------------------------
-- 5. RFM QUINTILE SCORES + SEGMENT LABEL
-- -----------------------------------------------------------------------------
WITH snapshot AS (
    SELECT MAX(purchase_date) + INTERVAL '1 day' AS snapshot_date FROM transactions
),
base AS (
    SELECT
        t.customer_id,
        DATE_PART('day', s.snapshot_date - MAX(t.purchase_date)) AS recency_days,
        COUNT(*)                                                   AS frequency,
        SUM(t.total_purchase_amount)                                AS monetary
    FROM transactions t CROSS JOIN snapshot s
    GROUP BY t.customer_id, s.snapshot_date
),
scored AS (
    SELECT
        customer_id, recency_days, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,   -- most recent = 5
        NTILE(5) OVER (ORDER BY frequency ASC)       AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)        AS m_score
    FROM base
)
SELECT *,
    (r_score + f_score + m_score) AS rfm_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2                  THEN 'New / Promising'
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk (High Value)'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Hibernating / Lost'
        WHEN r_score = 3 AND f_score <= 3 AND m_score <= 3  THEN 'Needs Attention'
        ELSE 'Potential Loyalist'
    END AS segment
FROM scored;

-- NOTE: sections 6-8 below reuse the query above. Since we're not creating
-- views/tables here, just wrap query #5 as a CTE named customer_segments,
-- e.g.:  WITH customer_segments AS ( <paste query #5 body> ) SELECT ... ;

-- -----------------------------------------------------------------------------
-- 6. SEGMENT PROFILE (revenue & churn concentration)
-- -----------------------------------------------------------------------------
WITH snapshot AS (
    SELECT MAX(purchase_date) + INTERVAL '1 day' AS snapshot_date FROM transactions
),
base AS (
    SELECT
        t.customer_id,
        DATE_PART('day', s.snapshot_date - MAX(t.purchase_date)) AS recency_days,
        COUNT(*)                                                   AS frequency,
        SUM(t.total_purchase_amount)                                AS monetary
    FROM transactions t CROSS JOIN snapshot s
    GROUP BY t.customer_id, s.snapshot_date
),
scored AS (
    SELECT
        customer_id, recency_days, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)       AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)        AS m_score
    FROM base
),
customer_segments AS (
    SELECT *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'New / Promising'
            WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk (High Value)'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Hibernating / Lost'
            WHEN r_score = 3 AND f_score <= 3 AND m_score <= 3  THEN 'Needs Attention'
            ELSE 'Potential Loyalist'
        END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                            AS customers,
       ROUND(AVG(recency_days), 1)                         AS avg_recency_days,
       ROUND(AVG(frequency), 1)                             AS avg_frequency,
       ROUND(AVG(monetary), 2)                               AS avg_monetary,
       ROUND(SUM(monetary), 2)                                AS total_revenue,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)      AS pct_customers
FROM customer_segments
GROUP BY segment
ORDER BY total_revenue DESC;

-- -----------------------------------------------------------------------------
-- 7. COHORT RETENTION (acquisition month cohorts)
-- -----------------------------------------------------------------------------
WITH first_order AS (
    SELECT customer_id, DATE_TRUNC('month', MIN(purchase_date)) AS cohort_month
    FROM transactions
    GROUP BY customer_id
),
orders_with_cohort AS (
    SELECT
        t.customer_id,
        f.cohort_month,
        DATE_TRUNC('month', t.purchase_date) AS order_month
    FROM transactions t
    JOIN first_order f ON f.customer_id = t.customer_id
)
SELECT
    cohort_month,
    order_month,
    (DATE_PART('year', order_month) - DATE_PART('year', cohort_month)) * 12
        + (DATE_PART('month', order_month) - DATE_PART('month', cohort_month)) AS period_number,
    COUNT(DISTINCT customer_id) AS active_customers
FROM orders_with_cohort
GROUP BY cohort_month, order_month
ORDER BY cohort_month, order_month;

-- -----------------------------------------------------------------------------
-- 8. CHURN RATE BY SEGMENT vs. PROVIDED "churn" LABEL
--    Finding: churn rate is ~19-21% in every segment -- the provided label is
--    essentially flat across behaviorally distinct groups, so it is not a
--    reliable churn signal on its own. Use RFM recency as the practical
--    churn-risk proxy instead.
-- -----------------------------------------------------------------------------
WITH snapshot AS (
    SELECT MAX(purchase_date) + INTERVAL '1 day' AS snapshot_date FROM transactions
),
base AS (
    SELECT
        t.customer_id,
        DATE_PART('day', s.snapshot_date - MAX(t.purchase_date)) AS recency_days,
        COUNT(*)                                                   AS frequency,
        SUM(t.total_purchase_amount)                                AS monetary
    FROM transactions t CROSS JOIN snapshot s
    GROUP BY t.customer_id, s.snapshot_date
),
scored AS (
    SELECT
        customer_id, recency_days, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)       AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)        AS m_score
    FROM base
),
customer_segments AS (
    SELECT *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'New / Promising'
            WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk (High Value)'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Hibernating / Lost'
            WHEN r_score = 3 AND f_score <= 3 AND m_score <= 3  THEN 'Needs Attention'
            ELSE 'Potential Loyalist'
        END AS segment
    FROM scored
)
SELECT cs.segment, ROUND(AVG(CAST(c.churn AS DOUBLE)), 3) AS churn_rate
FROM customer_segments cs
JOIN (SELECT DISTINCT customer_id, churn FROM transactions) c
  ON c.customer_id = cs.customer_id
GROUP BY cs.segment
ORDER BY churn_rate DESC;

-- -----------------------------------------------------------------------------
-- 9. TOP 10 HIGH-VALUE CUSTOMERS AT RISK (recent inactivity, historically high spend)
-- -----------------------------------------------------------------------------
WITH snapshot AS (
    SELECT MAX(purchase_date) + INTERVAL '1 day' AS snapshot_date FROM transactions
),
base AS (
    SELECT
        t.customer_id,
        DATE_PART('day', s.snapshot_date - MAX(t.purchase_date)) AS recency_days,
        COUNT(*)                                                   AS frequency,
        SUM(t.total_purchase_amount)                                AS monetary
    FROM transactions t CROSS JOIN snapshot s
    GROUP BY t.customer_id, s.snapshot_date
),
scored AS (
    SELECT
        customer_id, recency_days, frequency, monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)       AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)        AS m_score
    FROM base
),
customer_segments AS (
    SELECT *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'New / Promising'
            WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk (High Value)'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Hibernating / Lost'
            WHEN r_score = 3 AND f_score <= 3 AND m_score <= 3  THEN 'Needs Attention'
            ELSE 'Potential Loyalist'
        END AS segment
    FROM scored
)
SELECT customer_id, recency_days, frequency, monetary, segment
FROM customer_segments
WHERE segment = 'At Risk (High Value)'
ORDER BY monetary DESC
LIMIT 10;
