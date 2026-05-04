-- ============================================================
-- Retail Sales Performance Dashboard — Analysis Queries
-- Author: Satyam Thakur
-- Description: Multi-dimensional sales analysis using window
--              functions, CTEs, and conditional aggregation
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- Q1: Monthly Sales Revenue & Gross Profit Trend
-- ─────────────────────────────────────────────────────────────
SELECT
    dd.fiscal_year,
    dd.month_name,
    dd.month_number,
    COUNT(DISTINCT fs.sale_id)                AS total_transactions,
    SUM(fs.quantity)                          AS units_sold,
    ROUND(SUM(fs.net_revenue), 2)             AS net_revenue,
    ROUND(SUM(fs.gross_profit), 2)            AS gross_profit,
    ROUND(SUM(fs.gross_profit)
          / NULLIF(SUM(fs.net_revenue), 0) * 100, 2) AS margin_pct
FROM fact_sales fs
JOIN dim_date dd ON fs.date_id = dd.date_id
GROUP BY dd.fiscal_year, dd.month_name, dd.month_number
ORDER BY dd.fiscal_year, dd.month_number;


-- ─────────────────────────────────────────────────────────────
-- Q2: Regional Revenue Ranking with Running Total
-- ─────────────────────────────────────────────────────────────
WITH region_revenue AS (
    SELECT
        ds.region,
        ROUND(SUM(fs.net_revenue), 2) AS total_revenue,
        SUM(fs.quantity)              AS total_units
    FROM fact_sales fs
    JOIN dim_store ds ON fs.store_id = ds.store_id
    GROUP BY ds.region
)
SELECT
    region,
    total_revenue,
    total_units,
    RANK() OVER (ORDER BY total_revenue DESC)         AS revenue_rank,
    ROUND(total_revenue
          / SUM(total_revenue) OVER () * 100, 2)      AS revenue_share_pct,
    ROUND(SUM(total_revenue) OVER (ORDER BY total_revenue DESC
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW), 2) AS running_total
FROM region_revenue
ORDER BY revenue_rank;


-- ─────────────────────────────────────────────────────────────
-- Q3: Product Category Performance — Hierarchical ROLLUP
-- ─────────────────────────────────────────────────────────────
SELECT
    COALESCE(dp.category,    '[ ALL CATEGORIES ]') AS category,
    COALESCE(dp.subcategory, '[ ALL SUBCATEGORIES ]') AS subcategory,
    ROUND(SUM(fs.net_revenue), 2)   AS net_revenue,
    SUM(fs.quantity)                AS units_sold,
    ROUND(SUM(fs.gross_profit), 2)  AS gross_profit,
    ROUND(AVG(fs.unit_price), 2)    AS avg_unit_price
FROM fact_sales fs
JOIN dim_product dp ON fs.product_id = dp.product_id
GROUP BY ROLLUP(dp.category, dp.subcategory)
ORDER BY dp.category NULLS LAST, dp.subcategory NULLS LAST;


-- ─────────────────────────────────────────────────────────────
-- Q4: Month-over-Month Revenue Growth per Store
-- ─────────────────────────────────────────────────────────────
WITH monthly_store AS (
    SELECT
        ds.store_name,
        dd.fiscal_year,
        dd.month_number,
        ROUND(SUM(fs.net_revenue), 2) AS revenue
    FROM fact_sales fs
    JOIN dim_store ds ON fs.store_id  = ds.store_id
    JOIN dim_date  dd ON fs.date_id   = dd.date_id
    GROUP BY ds.store_name, dd.fiscal_year, dd.month_number
)
SELECT
    store_name,
    fiscal_year,
    month_number,
    revenue,
    LAG(revenue) OVER (PARTITION BY store_name ORDER BY fiscal_year, month_number) AS prev_month,
    ROUND(
        (revenue - LAG(revenue) OVER (PARTITION BY store_name ORDER BY fiscal_year, month_number))
        / NULLIF(LAG(revenue) OVER (PARTITION BY store_name ORDER BY fiscal_year, month_number), 0) * 100
    , 2) AS mom_growth_pct,
    ROUND(AVG(revenue) OVER (
        PARTITION BY store_name ORDER BY fiscal_year, month_number
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS rolling_3m_avg
FROM monthly_store
ORDER BY store_name, fiscal_year, month_number;


-- ─────────────────────────────────────────────────────────────
-- Q5: Sales Rep Quota Attainment Report
-- ─────────────────────────────────────────────────────────────
WITH rep_monthly_sales AS (
    SELECT
        sr.rep_id,
        sr.rep_name,
        ds.store_name,
        dd.month_number,
        dd.fiscal_year,
        sr.monthly_quota,
        ROUND(SUM(fs.net_revenue), 2) AS actual_sales
    FROM fact_sales fs
    JOIN dim_sales_rep sr ON fs.rep_id   = sr.rep_id
    JOIN dim_store     ds ON fs.store_id = ds.store_id
    JOIN dim_date      dd ON fs.date_id  = dd.date_id
    GROUP BY sr.rep_id, sr.rep_name, ds.store_name,
             dd.month_number, dd.fiscal_year, sr.monthly_quota
)
SELECT
    rep_name,
    store_name,
    fiscal_year,
    month_number,
    monthly_quota,
    actual_sales,
    ROUND(actual_sales - monthly_quota, 2)                           AS variance,
    ROUND(actual_sales / NULLIF(monthly_quota, 0) * 100, 1)          AS quota_attainment_pct,
    RANK() OVER (PARTITION BY fiscal_year, month_number ORDER BY actual_sales DESC) AS rank_this_month,
    CASE
        WHEN actual_sales >= monthly_quota * 1.1  THEN '🏆 Exceeded'
        WHEN actual_sales >= monthly_quota         THEN '✅ Met Quota'
        WHEN actual_sales >= monthly_quota * 0.9   THEN '⚠️  Near Quota'
        ELSE                                            '🔴 Below Quota'
    END AS quota_status
FROM rep_monthly_sales
ORDER BY fiscal_year, month_number, rank_this_month;


-- ─────────────────────────────────────────────────────────────
-- Q6: Top 10 & Bottom 10 Products by Revenue
-- ─────────────────────────────────────────────────────────────
WITH product_performance AS (
    SELECT
        dp.product_name,
        dp.category,
        ROUND(SUM(fs.net_revenue), 2)  AS net_revenue,
        SUM(fs.quantity)               AS units_sold,
        ROUND(SUM(fs.gross_profit), 2) AS gross_profit,
        DENSE_RANK() OVER (ORDER BY SUM(fs.net_revenue) DESC) AS revenue_rank
    FROM fact_sales fs
    JOIN dim_product dp ON fs.product_id = dp.product_id
    GROUP BY dp.product_id, dp.product_name, dp.category
)
-- Top 10
SELECT 'Top 10' AS tier, product_name, category, net_revenue, units_sold, revenue_rank
FROM product_performance WHERE revenue_rank <= 10

UNION ALL

-- Bottom 10
SELECT 'Bottom 10', product_name, category, net_revenue, units_sold, revenue_rank
FROM product_performance
WHERE revenue_rank > (SELECT COUNT(*) FROM product_performance) - 10
ORDER BY tier, revenue_rank;
