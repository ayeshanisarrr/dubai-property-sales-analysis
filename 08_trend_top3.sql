-- monthly sales for the 3 recommended areas, 2020 to 2022


SELECT sale_year, sale_month, area_name, COUNT(*) AS sales
FROM dbo.clean_sales
WHERE area_name IN ('Business Bay', 'Al Khairan First', 'Al Merkadh')
GROUP BY sale_year, sale_month, area_name
ORDER BY area_name, sale_year, sale_month;


-- Result: yearly totals match the earlier queries

-- (2022: Business Bay 8,123, Al Khairan First 3,510, Al Merkadh 5,219;
--  2021: 3,960, 924, 2,573)
-- Business Bay's monthly sales in 2022 ranged from 449 (June) to 1,013 (September)
-- Al Khairan First sold under 40 a month from January to July 2021, then 209 to 387
-- a month in 2022. It sold 866 in 2020 and 924 in 2021, so its 2021 base is low
-- Al Merkadh was uneven: 669 sales in June 2021 (26.0% of its 2021 total) and
-- 894 and 943 in November and December 2022 (35.2% of its 2022 total)