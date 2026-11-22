/*
Project:  Dubai Residential Sales Analysis,
File:     01_cleaning.sql
Purpose:  Check the raw data, then build dbo.clean_sales
Database: DubaiProperty (SQL Server)
Source:   dbo.Transactions (imported from the Kaggle CSV of Dubai Land Department open data)
*/

USE DubaiProperty;
GO

-- PART A: CHECK THE RAW DATA

-- A1. Size and date range.
-- Dates are stored as day-month-year text. Style 105 reads them correctly.
-- The default format failed on about 62% of them and swapped day and month on many of the rest.

SELECT COUNT(*) AS total_rows,
       MIN(TRY_CONVERT(date, instance_date, 105)) AS first_date,
       MAX(TRY_CONVERT(date, instance_date, 105)) AS last_date,
       SUM(CASE WHEN TRY_CONVERT(date, instance_date, 105) IS NULL THEN 1 ELSE 0 END) AS dates_not_read
FROM dbo.Transactions;

-- A1b. 5 rows have no date at all (blank). The 2020-2022 filter excludes them automatically.

SELECT transaction_id, instance_date
FROM dbo.Transactions
WHERE TRY_CONVERT(date, instance_date, 105) IS NULL;

-- A2. Transaction types. The file mixes sales, mortgages and gifts.
-- Only Sales are kept for this analysis.

SELECT trans_group_en, COUNT(*) AS n
FROM dbo.Transactions
GROUP BY trans_group_en;

-- A3. Off-plan vs ready labels (all transaction types).

SELECT reg_type_en, COUNT(*) AS n
FROM dbo.Transactions
GROUP BY reg_type_en;

-- A4. Property types and sub-types.
-- Many villa rows have an empty sub-type, so villas are selected by property type.
-- Flats are selected as type "Unit" with sub-type "Flat".

SELECT property_type_en, property_sub_type_en, COUNT(*) AS n
FROM dbo.Transactions
GROUP BY property_type_en, property_sub_type_en
ORDER BY n DESC;

-- A5. The text "null" in key columns (stored as text, not as a real empty value).

SELECT
  SUM(CASE WHEN actual_worth = 'null' THEN 1 ELSE 0 END)      AS null_worth,
  SUM(CASE WHEN meter_sale_price = 'null' THEN 1 ELSE 0 END)  AS null_price,
  SUM(CASE WHEN procedure_area = 'null' THEN 1 ELSE 0 END)    AS null_area
FROM dbo.Transactions;

-- A6. Kinds of sales inside "Sales".
-- Kept: Sell, Sell - Pre registration, Delayed Sell (92.6% of sales rows).
-- Excluded: the other 15 types, which look like development, lease-to-own
-- and land registrations rather than ordinary sales.

SELECT procedure_name_en, COUNT(*) AS n
FROM dbo.Transactions
WHERE trans_group_en = 'Sales'
GROUP BY procedure_name_en
ORDER BY n DESC;

-- A7. Price per sqm range for the rows in scope (before the outlier rule).
-- Used to choose the outlier bounds in Part B.

WITH f AS (
  SELECT TRY_CAST(meter_sale_price AS float) AS price_sqm
  FROM dbo.Transactions
  WHERE trans_group_en = 'Sales'
    AND (property_type_en = 'Villa'
         OR (property_type_en = 'Unit' AND property_sub_type_en = 'Flat'))
    AND TRY_CONVERT(date, instance_date, 105) BETWEEN '2020-01-01' AND '2022-12-31'
)
SELECT DISTINCT
  MIN(price_sqm) OVER ()                                          AS min_price,
  PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY price_sqm) OVER () AS p01,
  PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY price_sqm) OVER () AS median_price,
  PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY price_sqm) OVER () AS p99,
  MAX(price_sqm) OVER ()                                          AS max_price
FROM f
WHERE price_sqm > 0;


-- PART B: BUILD THE CLEAN TABLE


-- B1. Build dbo.clean_sales. The raw table is not changed.
-- Rules: Sales only; three sale types; flats and villas; 2020 to 2022;
-- value, price and size above zero; price per sqm between 1,000 and 100,000.

DROP TABLE IF EXISTS dbo.clean_sales;

SELECT
    transaction_id,
    TRY_CONVERT(date, instance_date, 105)         AS sale_date,
    YEAR(TRY_CONVERT(date, instance_date, 105))   AS sale_year,
    MONTH(TRY_CONVERT(date, instance_date, 105))  AS sale_month,
    area_name_en                                  AS area_name,
    CASE WHEN property_type_en = 'Villa' THEN 'Villa' ELSE 'Flat' END AS property_kind,
    reg_type_en,
    procedure_name_en,
    TRY_CAST(actual_worth AS float)               AS worth,
    TRY_CAST(meter_sale_price AS float)           AS price_sqm,
    TRY_CAST(procedure_area AS float)             AS area_sqm
INTO dbo.clean_sales
FROM dbo.Transactions
WHERE trans_group_en = 'Sales'
  AND procedure_name_en IN ('Sell', 'Sell - Pre registration', 'Delayed Sell')
  AND (property_type_en = 'Villa'
       OR (property_type_en = 'Unit' AND property_sub_type_en = 'Flat'))
  AND TRY_CONVERT(date, instance_date, 105) BETWEEN '2020-01-01' AND '2022-12-31'
  AND TRY_CAST(actual_worth AS float) > 0
  AND TRY_CAST(meter_sale_price AS float) BETWEEN 1000 AND 100000
  AND TRY_CAST(procedure_area AS float) > 0;

SELECT COUNT(*) AS clean_rows FROM dbo.clean_sales;

-- B2. Cleaning log: rows left after each rule.
-- The last number must equal clean_rows from B1.

WITH s AS (
  SELECT trans_group_en, procedure_name_en, property_type_en, property_sub_type_en,
         TRY_CONVERT(date, instance_date, 105) AS d,
         TRY_CAST(actual_worth AS float) AS worth,
         TRY_CAST(meter_sale_price AS float) AS price_sqm,
         TRY_CAST(procedure_area AS float) AS area_sqm
  FROM dbo.Transactions
),
f AS (
  SELECT *,
    CASE WHEN trans_group_en = 'Sales' THEN 1 ELSE 0 END AS k1,
    CASE WHEN procedure_name_en IN ('Sell','Sell - Pre registration','Delayed Sell') THEN 1 ELSE 0 END AS k2,
    CASE WHEN property_type_en = 'Villa'
           OR (property_type_en = 'Unit' AND property_sub_type_en = 'Flat') THEN 1 ELSE 0 END AS k3,
    CASE WHEN d BETWEEN '2020-01-01' AND '2022-12-31' THEN 1 ELSE 0 END AS k4,
    CASE WHEN worth > 0 AND price_sqm > 0 AND area_sqm > 0 THEN 1 ELSE 0 END AS k5,
    CASE WHEN price_sqm BETWEEN 1000 AND 100000 THEN 1 ELSE 0 END AS k6
  FROM s
)
SELECT SUM(k1)                   AS sales_only,
       SUM(k1*k2)                AS after_sale_types,
       SUM(k1*k2*k3)             AS flats_and_villas,
       SUM(k1*k2*k3*k4)          AS y2020_to_2022,
       SUM(k1*k2*k3*k4*k5)       AS valid_numbers,
       SUM(k1*k2*k3*k4*k5*k6)    AS after_price_rule
FROM f;

-- B3. Sanity checks on the clean table.
-- Sales per year should move in a believable way.

SELECT sale_year, COUNT(*) AS n
FROM dbo.clean_sales
GROUP BY sale_year
ORDER BY sale_year;

-- "Sell - Pre registration" should be mostly off-plan.

SELECT procedure_name_en, reg_type_en, COUNT(*) AS n
FROM dbo.clean_sales
GROUP BY procedure_name_en, reg_type_en
ORDER BY procedure_name_en, n DESC;

-- B4. Check that price per sqm matches value divided by size.
-- Result: 0 of 148,397 rows differ by more than 5%.

SELECT COUNT(*) AS rows_checked,
       SUM(CASE WHEN ABS(worth / area_sqm - price_sqm) / price_sqm > 0.05 THEN 1 ELSE 0 END) AS rows_off_by_more_than_5pct
FROM dbo.clean_sales;

-- B5. List all area names to check for spelling variants that would split one area in two.
-- Result: the counts add up to 148,397 (matches clean_rows). No obvious duplicates found.
-- Names are kept exactly as they appear in the data.
SELECT area_name, COUNT(*) AS n
FROM dbo.clean_sales
GROUP BY area_name
ORDER BY area_name;

-- RESULTS SUMMARY
-- A1: 1,047,965 rows, 7 Mar 1995 to 17 Mar 2023. 5 rows have no date.
-- A2: Sales 787,892, Mortgages 224,183, Gifts 35,890.
-- A3: Existing Properties 739,266, Off-Plan Properties 308,699 (all transaction types).
-- A4: Flat 614,233; Villa 214,855 (128,330 of them have no sub-type). All transaction types.
-- A5: 3,805 rows have the text "null" in the value column. None in price or size.
-- A6: Sell 348,060 + Sell - Pre registration 290,369 + Delayed Sell 91,486 = 729,915 (92.6% of sales).
-- A7: price per sqm for flats and villas sold in 2020-2022 (all sale types, before the sale-type and outlier rules): min 0.01, 1st percentile 3,605, median 11,846, 99th percentile 42,362, max 674,779.
-- B1: clean_sales has 148,397 rows.
-- B2: 787,892 sales > 729,915 sale types > 580,111 flats and villas > 148,546 in 2020-2022 > 148,534 valid numbers > 148,397 after price rule.
-- B3: sales per year: 2020 = 26,319, 2021 = 46,877, 2022 = 75,201. All 76,631 clean "Sell - Pre registration" rows are off-plan, and none of the "Sell" or "Delayed Sell" rows are.
-- B4: 0 of 148,397 rows differ by more than 5%. 
