-- Q1: which 10 areas had the most residential sales in 2022?
-- Table: clean_sales (built in 01_cleaning.sql), flats and villas, 2020-2022

USE DubaiProperty;
GO

-- Top 10 areas by number of sales, plus each area's share of all 2022 sales

WITH area_sales AS (
    SELECT area_name, COUNT(*) AS sales_2022
    FROM dbo.clean_sales
    WHERE sale_year = 2022
    GROUP BY area_name
)
SELECT TOP 10
    area_name,
    sales_2022,
    CAST(100.0 * sales_2022 / SUM(sales_2022) OVER () AS decimal(5,1)) AS pct_of_all_2022_sales
FROM area_sales
ORDER BY sales_2022 DESC;

-- Top 10 = 44,769 of 75,201 sales (59.5%). Business Bay is first with 8,123 (10.8%).


-- Same 10 areas, split into flats and villas

WITH top10 AS (
    SELECT TOP 10 area_name
    FROM dbo.clean_sales
    WHERE sale_year = 2022
    GROUP BY area_name
    ORDER BY COUNT(*) DESC
)
SELECT c.area_name, c.property_kind, COUNT(*) AS sales_2022
FROM dbo.clean_sales AS c
JOIN top10 AS t ON t.area_name = c.area_name
WHERE c.sale_year = 2022
GROUP BY c.area_name, c.property_kind
ORDER BY c.area_name, c.property_kind;

-- Wadi Al Safa 5 is the only villa-led area here (2,120 of 2,839 sales).
-- The other areas are mostly flats.