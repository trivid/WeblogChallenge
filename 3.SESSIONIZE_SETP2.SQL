DROP TABLE IF EXISTS VWEI02.WEBLOG_SESSIONIZE_SETP2 ;
CREATE TABLE VWEI02.WEBLOG_SESSIONIZE_SETP2 
(
  CLIENT_PORT	VARCHAR(50)
, REQUEST_TIME	TIMESTAMP
, SESSION_5_MIN		BIGINT
, SESSION_10_MIN		BIGINT
, SESSION_15_MIN		BIGINT
)
COMMENT 'Weblog Sessionization Step 2 where request are bucketed into sessions based on the idle time between requests.'
STORED AS AVRO;
-- Originally, I had a solution that buckets the requests into 15 minutes chunks starting from the first request
-- but then I realized that counting session based on idle time makes more sense for web browsing.

INSERT OVERWRITE TABLE VWEI02.WEBLOG_SESSIONIZE_SETP2 
SELECT 
  CLIENT_PORT
, REQUEST_TIME
, SUM(CASE WHEN DIFFERENCE >= 5 * 60 THEN 1 ELSE 0 END) OVER (PARTITION BY CLIENT_PORT ORDER BY REQUEST_TIME) + 1 AS SESSION_5_MIN
, SUM(CASE WHEN DIFFERENCE >= 10 * 60 THEN 1 ELSE 0 END) OVER (PARTITION BY CLIENT_PORT ORDER BY REQUEST_TIME) + 1 AS SESSION_10_MIN
, SUM(CASE WHEN DIFFERENCE >= 15 * 60 THEN 1 ELSE 0 END) OVER (PARTITION BY CLIENT_PORT ORDER BY REQUEST_TIME) + 1 AS SESSION_15_MIN  
FROM VWEI02.WEBLOG_SESSIONIZE_SETP1 GROUP BY CLIENT_PORT, REQUEST_TIME, DIFFERENCE;
-- The idea for this query is that whenever the gap between two request is more than the session threshold, the cumulative sum is increased by 1, signaling a new session.
