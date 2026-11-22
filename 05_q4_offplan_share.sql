-- Q4: what share of each area's 2022 sales were off-plan?
-- only areas with 100+ sales in 2022


-- off-plan share by area

SELECT
    area_name,
    COUNT(*) AS total_sales,
    SUM(CASE WHEN reg_type_en = 'Off-Plan Properties' THEN 1 ELSE 0 END) AS off_plan,
    SUM(CASE WHEN reg_type_en = 'Existing Properties' THEN 1 ELSE 0 END) AS ready,
    CAST(100.0 * SUM(CASE WHEN reg_type_en = 'Off-Plan Properties' THEN 1 ELSE 0 END)
         / COUNT(*) AS decimal(5,1)) AS pct_off_plan
FROM dbo.clean_sales
WHERE sale_year = 2022
GROUP BY area_name
HAVING COUNT(*) >= 100
ORDER BY pct_off_plan DESC;

-- same thing for the whole market

SELECT
    COUNT(*) AS total_sales,
    SUM(CASE WHEN reg_type_en = 'Off-Plan Properties' THEN 1 ELSE 0 END) AS off_plan,
    CAST(100.0 * SUM(CASE WHEN reg_type_en = 'Off-Plan Properties' THEN 1 ELSE 0 END)
         / COUNT(*) AS decimal(5,1)) AS pct_off_plan
FROM dbo.clean_sales
WHERE sale_year = 2022;


-- Whole market: 41,559 of 75,201 sales (55.3%) were off-plan in 2022
-- Of the top 10 areas by sales, 7 were above the market share and 3 below:
-- Al Barsha South Fourth (51.0%), Palm Jumeirah (47.8%) and Marsa Dubai (41.0%)