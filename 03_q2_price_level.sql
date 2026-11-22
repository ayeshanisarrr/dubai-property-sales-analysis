-- Q2: what is the middle price per sqm in the top 10 areas,
-- and how does it compare with Dubai overall? (2022 only)
-- Using the median, not the average, because a few luxury deals push the average up.
-- Flats and villas are kept separate so the comparison is fair

USE DubaiProperty;
GO

-- same top 10 areas as Q1

WITH top10 AS (
    SELECT TOP 10 area_name
    FROM dbo.clean_sales
    WHERE sale_year = 2022
    GROUP BY area_name
    ORDER BY COUNT(*) DESC
),

-- median price per sqm and number of sales for each area, flats and villas separately

med AS (
    SELECT DISTINCT
        c.area_name,
        c.property_kind,
        COUNT(*) OVER (PARTITION BY c.area_name, c.property_kind) AS sales_2022,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.price_sqm)
            OVER (PARTITION BY c.area_name, c.property_kind) AS median_price_sqm
    FROM dbo.clean_sales AS c
    JOIN top10 AS t ON t.area_name = c.area_name
    WHERE c.sale_year = 2022
),

-- median price per sqm across all of Dubai, for flats and villas

dubai AS (
    SELECT DISTINCT
        property_kind,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price_sqm)
            OVER (PARTITION BY property_kind) AS dubai_median_price_sqm
    FROM dbo.clean_sales
    WHERE sale_year = 2022
)

-- compare each area with Dubai. Groups under 30 sales are hidden,
-- a median from so few sales isn't reliable (e.g. Marsa Dubai villas = 8 sales)

SELECT
    m.area_name,
    m.property_kind,
    m.sales_2022,
    CAST(m.median_price_sqm AS decimal(10,0))       AS median_price_sqm,
    CAST(d.dubai_median_price_sqm AS decimal(10,0)) AS dubai_median_price_sqm,
    CAST(100.0 * (m.median_price_sqm / d.dubai_median_price_sqm - 1) AS decimal(6,1)) AS pct_vs_dubai
FROM med AS m
JOIN dubai AS d ON d.property_kind = m.property_kind
WHERE m.sales_2022 >= 30
ORDER BY m.property_kind, m.median_price_sqm DESC;

-- Result (flats): Palm Jumeirah was the most expensive at 32,110 per sqm
-- (99.2% above Dubai's flat median of 16,119). Wadi Al Safa 5 was the cheapest
-- at 7,889 (51.1% below)
-- Result (villas): Palm Jumeirah was the most expensive at 29,740 per sqm
-- (227.5% above Dubai's villa median of 9,080), from 134 sales.
-- Wadi Al Safa 5 was the cheapest villa group shown, at 9,537 (5.0% above).
-- Marsa Dubai villas are hidden (8 sales)   
