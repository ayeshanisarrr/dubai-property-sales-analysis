-- Q5: which areas had the most flat sales under 1.5M in 2022?
-- flats only, value assumed to be AED


-- top 10 areas by number of flats sold under 1.5M

SELECT TOP 10
    area_name,
    SUM(CASE WHEN worth < 1500000 THEN 1 ELSE 0 END) AS under_1_5m,
    COUNT(*) AS all_flats,
    CAST(100.0 * SUM(CASE WHEN worth < 1500000 THEN 1 ELSE 0 END)
         / COUNT(*) AS decimal(5,1)) AS pct_under
FROM dbo.clean_sales
WHERE sale_year = 2022
  AND property_kind = 'Flat'
GROUP BY area_name
ORDER BY under_1_5m DESC;

-- whole market, to compare against
SELECT
    SUM(CASE WHEN worth < 1500000 THEN 1 ELSE 0 END) AS under_1_5m,
    COUNT(*) AS all_flats,
    CAST(100.0 * SUM(CASE WHEN worth < 1500000 THEN 1 ELSE 0 END)
         / COUNT(*) AS decimal(5,1)) AS pct_under
FROM dbo.clean_sales
WHERE sale_year = 2022
  AND property_kind = 'Flat';


-- Result: 58.8% of 2022 flat sales were under 1.5M (36,448 of 62,026).
-- Al Barsha South Fourth had the most (5,290 of 5,388 flats, 98.2%), then
-- Business Bay (5,074, 62.5%) and Al Merkadh (3,691, 71.8%)
-- Of the 10 areas shown, four had over 95% of flat sales under 1.5M: Al Barshaa South Third (99.4%),
-- Al Barsha South Fourth (98.2%), Al Warsan First (98.2%) and Jabal Ali First (95.7%)
-- Marsa Dubai (24.6%) and Al Khairan First (32.3%) had many flat sales but few under 1.5M