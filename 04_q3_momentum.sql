-- Q3: which areas grew or dropped the most in sales, 2021 to 2022
-- only areas with 100+ sales in 2021, small areas give silly percentages

USE DubaiProperty;
GO

-- 2021 sales per area (100+ only)

WITH areas_2021 AS (
    SELECT area_name, COUNT(*) AS sales_2021
    FROM dbo.clean_sales
    WHERE sale_year = 2021
    GROUP BY area_name
    HAVING COUNT(*) >= 100
),

-- 2022 sales per area

areas_2022 AS (
    SELECT area_name, COUNT(*) AS sales_2022
    FROM dbo.clean_sales
    WHERE sale_year = 2022
    GROUP BY area_name
),

-- whole market, to see if an area beat the market or lagged behind it

market AS (
    SELECT
        SUM(CASE WHEN sale_year = 2021 THEN 1 ELSE 0 END) AS total_2021,
        SUM(CASE WHEN sale_year = 2022 THEN 1 ELSE 0 END) AS total_2022
    FROM dbo.clean_sales
)

SELECT
    a.area_name,
    a.sales_2021,
    ISNULL(b.sales_2022, 0) AS sales_2022,
    ISNULL(b.sales_2022, 0) - a.sales_2021 AS sales_change,
    CAST(100.0 * (ISNULL(b.sales_2022, 0) - a.sales_2021) / a.sales_2021 AS decimal(7,1)) AS pct_change,
    CAST(100.0 * (m.total_2022 - m.total_2021) / m.total_2021 AS decimal(7,1)) AS market_pct_change
FROM areas_2021 AS a
LEFT JOIN areas_2022 AS b ON b.area_name = a.area_name
CROSS JOIN market AS m
ORDER BY pct_change DESC;


-- Result: Market sales grew 60.4% from 2021 to 2022 (46,877 to 75,201).
-- Of the 47 areas with 100+ sales in 2021, 22 grew faster than the market
-- and 11 had fewer sales in 2022.
-- Al Wasl had the biggest % rise (+1,223.6%, from 165 to 2,184 sales),
-- but Business Bay added the most sales (+4,163, from 3,960 to 8,123).
-- Al Yufrah 3 had the biggest % fall (-54.5%), and Al Hebiah Fourth lost
-- the most sales (-671)