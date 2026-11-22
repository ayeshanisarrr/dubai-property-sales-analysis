-- Q6: which 3 areas rank best on demand (Q1), growth (Q3) and flats under 1.5M (Q5)?
-- rank 1 = best for each, add the 3 ranks, lowest total wins
-- tie = more 2022 sales wins
-- only the areas with 100+ sales in 2021



DROP TABLE IF EXISTS dbo.area_scores;

WITH areas_2021 AS (
    SELECT area_name, COUNT(*) AS sales_2021
    FROM dbo.clean_sales
    WHERE sale_year = 2021
    GROUP BY area_name
    HAVING COUNT(*) >= 100
),

areas_2022 AS (
    SELECT
        area_name,
        COUNT(*) AS sales_2022,
        SUM(CASE WHEN property_kind = 'Flat' AND worth < 1500000 THEN 1 ELSE 0 END) AS flats_under_1_5m
    FROM dbo.clean_sales
    WHERE sale_year = 2022
    GROUP BY area_name
),

joined AS (
    SELECT
        a.area_name,
        a.sales_2021,
        ISNULL(b.sales_2022, 0) AS sales_2022,
        ISNULL(b.flats_under_1_5m, 0) AS flats_under_1_5m,
        100.0 * (ISNULL(b.sales_2022, 0) - a.sales_2021) / a.sales_2021 AS pct_change
    FROM areas_2021 AS a
    LEFT JOIN areas_2022 AS b ON b.area_name = a.area_name
),

ranks AS (
    SELECT *,
        RANK() OVER (ORDER BY sales_2022 DESC)       AS rank_demand,
        RANK() OVER (ORDER BY pct_change DESC)       AS rank_growth,
        RANK() OVER (ORDER BY flats_under_1_5m DESC) AS rank_entry
    FROM joined
)

SELECT
    area_name, sales_2021, sales_2022, flats_under_1_5m, pct_change,
    rank_demand, rank_growth, rank_entry,
    rank_demand + rank_growth + rank_entry AS total_score
INTO dbo.area_scores
FROM ranks;

-- top 10 by score, lowest is best

SELECT TOP 10
    area_name,
    sales_2022,
    CAST(pct_change AS decimal(7,1)) AS pct_change,
    flats_under_1_5m,
    rank_demand, rank_growth, rank_entry,
    total_score
FROM dbo.area_scores
ORDER BY total_score ASC, sales_2022 DESC;


-- Result: Business Bay ranked first (score 16), then Al Khairan First (19) and Al Merkadh (21)
-- Jabal Ali First was fourth with 22, one point behind Al Merkadh
-- Business Bay: 1st on demand (8,123 sales), 13th on growth (+105.1%), 2nd on flats under 1.5M (5,074)
-- Al Khairan First: 6th on demand (3,510), 3rd on growth (+279.9%), 10th on flats under 1.5M (1,134)
-- Al Merkadh: 4th on demand (5,219), 14th on growth (+102.8%), 3rd on flats under 1.5M (3,691)


-- off-plan share and median price per sqm for the top 3 (2022)

WITH top3 AS (
    SELECT TOP 3 area_name
    FROM dbo.area_scores
    ORDER BY total_score ASC, sales_2022 DESC
)
SELECT DISTINCT
    c.area_name,
    c.property_kind,
    COUNT(*) OVER (PARTITION BY c.area_name, c.property_kind) AS sales_2022,
    CAST(100.0 * SUM(CASE WHEN c.reg_type_en = 'Off-Plan Properties' THEN 1 ELSE 0 END)
         OVER (PARTITION BY c.area_name, c.property_kind)
         / COUNT(*) OVER (PARTITION BY c.area_name, c.property_kind) AS decimal(5,1)) AS pct_off_plan,
    CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY c.price_sqm)
         OVER (PARTITION BY c.area_name, c.property_kind) AS decimal(10,0)) AS median_price_sqm
FROM dbo.clean_sales AS c
JOIN top3 AS t ON t.area_name = c.area_name
WHERE c.sale_year = 2022
ORDER BY c.area_name, c.property_kind;


-- Result: share of 2022 sales that were off-plan (flats and villas, from Q4): Al Merkadh 90.9%,
-- Al Khairan First 76.2%, Business Bay 67.5%. All three are above the market's 55.3%.
-- Share of flat sales only: Al Merkadh 92.3%, Al Khairan First 76.2%, Business Bay 67.5%
-- Median price per sqm, flats: Business Bay 19,128, Al Khairan First 19,217, Al Merkadh 18,299
-- Al Merkadh villas: 80 sales, 0% off-plan, median 20,000 (small sample)



-- check: does the top 3 change if one of the 3 ranks is left out?

WITH alt AS (
    SELECT area_name, sales_2022,
        RANK() OVER (ORDER BY rank_demand + rank_growth + rank_entry, sales_2022 DESC) AS pos_all,
        RANK() OVER (ORDER BY rank_demand + rank_growth, sales_2022 DESC)               AS pos_no_entry,
        RANK() OVER (ORDER BY rank_demand + rank_entry, sales_2022 DESC)                AS pos_no_growth,
        RANK() OVER (ORDER BY rank_growth + rank_entry, sales_2022 DESC)                AS pos_no_demand
    FROM dbo.area_scores
)
SELECT *
FROM alt
WHERE pos_all <= 3 OR pos_no_entry <= 3 OR pos_no_growth <= 3 OR pos_no_demand <= 3
ORDER BY pos_all;


-- Result: Business Bay and Al Khairan First were in the top 3 under 3 of the 4 scoring rules.
-- Business Bay: 1st with all three ranks, 2nd without entry-level, 1st without growth, 4th without demand.
-- Al Khairan First: 2nd with all three, 1st without entry-level, 8th without growth, 2nd without demand.
-- Al Merkadh (3rd in the main score) was in the top 3 under only 2 of the 4 rules:
-- 3rd with all three and 3rd without growth, but 6th without entry-level and 5th without demand.
-- Third place depends on the weights: Al Wasl was 3rd without entry-level,
-- Al Barsha South Fourth 2nd without growth, and Jabal Ali First 1st without demand.


