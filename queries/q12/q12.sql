--Find all customers who viewed items of a given category on the web
--in a given month and year that was followed by an in-store purchase in the three
--consecutive months.

-- Resources

--1)
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE1};
CREATE VIEW IF NOT EXISTS ${hiveconf:TEMP_TABLE1} AS
SELECT c.wcs_item_sk AS item,
  c.wcs_user_sk AS uid,
  c.wcs_click_date_sk AS c_date,
  c.wcs_click_time_sk AS c_time
FROM web_clickstreams c
LEFT SEMI JOIN (
  SELECT d_date_sk
  FROM date_dim d
  WHERE d.d_date >= '${hiveconf:q12_startDate}'
  AND   d.d_date <= '${hiveconf:q12_endDate1}'
) dd ON ( c.wcs_click_date_sk=dd.d_date_sk )
JOIN item i ON c.wcs_item_sk = i.i_item_sk
WHERE i.i_category IN (${hiveconf:q12_i_category_IN})
AND c.wcs_user_sk IS NOT NULL
CLUSTER BY c_date, c_time
;


--2)
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE2};
CREATE VIEW IF NOT EXISTS ${hiveconf:TEMP_TABLE2} AS
SELECT ss.ss_item_sk AS item,
  ss.ss_customer_sk AS uid,
  ss.ss_sold_date_sk AS s_date,
  ss.ss_sold_time_sk AS s_time
FROM store_sales ss
LEFT SEMI JOIN (
  SELECT d_date_sk
  FROM date_dim d
  WHERE d.d_date >= '${hiveconf:q12_startDate}'
  AND   d.d_date <= '${hiveconf:q12_endDate2}'
) dd ON ( ss.ss_sold_date_sk=dd.d_date_sk )
JOIN item i ON ss.ss_item_sk = i.i_item_sk
WHERE i.i_category IN (${hiveconf:q12_i_category_IN})
AND ss.ss_customer_sk IS NOT NULL
CLUSTER BY s_date, s_time
;


--Result  --------------------------------------------------------------------
--keep result human readable
set hive.exec.compress.output=false;
set hive.exec.compress.output;

DROP TABLE IF EXISTS ${hiveconf:RESULT_TABLE};
CREATE TABLE ${hiveconf:RESULT_TABLE} (
  c_date BIGINT,
  s_date BIGINT,
  uid    BIGINT
)
ROW FORMAT DELIMITED FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'
STORED AS ${env:BIG_BENCH_hive_default_fileformat_result_table}  LOCATION '${hiveconf:RESULT_DIR}';

-- the real query part
INSERT INTO TABLE ${hiveconf:RESULT_TABLE}
SELECT DISTINCT c_date, s_date, s.uid
FROM ${hiveconf:TEMP_TABLE1} c
JOIN ${hiveconf:TEMP_TABLE2} s ON c.uid = s.uid
WHERE c.c_date < s.s_date
;

--TODO: have to fix partition

-- cleanup -------------------------------------------------------------
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE1};
DROP VIEW IF EXISTS ${hiveconf:TEMP_TABLE2};
