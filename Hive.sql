CREATE DATABASE IF NOT EXISTS VWEI02;
CREATE EXTERNAL TABLE IF NOT EXISTS VWEI02.WEBLOG_EXT
(
  REQUEST_TIME				VARCHAR(50)
, elb						VARCHAR(100)
, client_port				VARCHAR(50)
, backend_port				VARCHAR(50)
, request_processing_time	VARCHAR(50)
, backend_processing_time	VARCHAR(50)
, response_processing_time	VARCHAR(50)
, elb_status_code			VARCHAR(10)
, backend_status_code		VARCHAR(10)
, received_bytes			VARCHAR(10)
, sent_bytes				VARCHAR(10)
, request					VARCHAR(256)
, user_agent				VARCHAR(256)
, ssl_cipher				VARCHAR(30)
, ssl_protocol				VARCHAR(20)
)
COMMENT 'External table for Weblog Practice with string fields.'
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
   "separatorChar" = " ",
   "quoteChar"     = '"',
   "escapeChar"    = "\\"
)  
STORED AS TEXTFILE
location 'hdfs:///sandbox/vwei02';

DROP TABLE IF EXISTS VWEI02.WEBLOG;
CREATE TABLE VWEI02.WEBLOG
(
  REQUEST_TIME				TIMESTAMP
, elb						VARCHAR(100)
, client_port				VARCHAR(50)
, backend_port				VARCHAR(50)
, request_processing_time	DECIMAL(16,6)
, backend_processing_time	DECIMAL(16,6)
, response_processing_time	DECIMAL(16,6)
, elb_status_code			VARCHAR(10)
, backend_status_code		VARCHAR(10)
, received_bytes			BIGINT
, sent_bytes				BIGINT
, request					VARCHAR(256)
, user_agent				VARCHAR(256)
, ssl_cipher				VARCHAR(30)
, ssl_protocol				VARCHAR(20)
)
COMMENT 'Raw table for Weblog Practice.'
STORED AS AVRO
;

INSERT OVERWRITE TABLE VWEI02.WEBLOG 
SELECT 
  CAST(regexp_replace(REQUEST_TIME,'[T,Z]',' ') AS TIMESTAMP) as request_time
, elb						 
, client_port				
, backend_port				
, request_processing_time	
, backend_processing_time	
, response_processing_time	
, elb_status_code			
, backend_status_code		
, received_bytes			
, sent_bytes				
, request					
, user_agent				
, ssl_cipher
, ssl_protocol				
FROM VWEI02.WEBLOG_EXT
;

DROP TABLE IF EXISTS VWEI02.WEBLOG_SESSIONIZE_SETP1;
CREATE TABLE VWEI02.WEBLOG_SESSIONIZE_SETP1 
(
  CLIENT_PORT	VARCHAR(50)
, REQUEST_TIME	TIMESTAMP
, DIFFERENCE	BIGINT
)
COMMENT 'Weblog Sessionization Step 1 where the difference in seconds between each request is calculated for each client.'
STORED AS AVRO;

INSERT OVERWRITE TABLE VWEI02.WEBLOG_SESSIONIZE_SETP1
SELECT 
  CLIENT_PORT
, REQUEST_TIME
, cast(FIRST_VALUE(REQUEST_TIME) OVER (PARTITION BY CLIENT_PORT ORDER BY REQUEST_TIME ROWS BETWEEN 1 PRECEDING AND CURRENT ROW ) as bigint) - cast(REQUEST_TIME as bigint) AS DIFFERENCE
FROM VWEI02.WEBLOG 
group by REQUEST_TIME, client_port;

DROP TABLE IF EXISTS VWEI02.WEBLOG_SESSIONIZE_SETP2 ;
CREATE TABLE VWEI02.WEBLOG_SESSIONIZE_SETP2 
(
  CLIENT_PORT	VARCHAR(50)
, REQUEST_TIME	TIMESTAMP
, SESSION		BIGINT
)
COMMENT 'Weblog Sessionization Step 2 where request are bucketed into sessions based on their division of accumulative difference with the session timeframe.'
STORED AS AVRO;

INSERT OVERWRITE TABLE VWEI02.WEBLOG_SESSIONIZE_SETP2 
SELECT 
  CLIENT_PORT
, REQUEST_TIME
, CASE WHEN CEIL(SUM(DIFFERENCE) OVER (PARTITION BY CLIENT_PORT ORDER BY REQUEST_TIME) / (15 * 60)) = 0 THEN 1 -- The first request will have 0 difference, and we want to count it as 1
       ELSE CEIL(SUM(DIFFERENCE) OVER (PARTITION BY CLIENT_PORT ORDER BY REQUEST_TIME) / (15 * 60)) 
  END AS SESSION
FROM VWEI02.WEBLOG_SESSIONIZE_SETP1 GROUP BY CLIENT_PORT, REQUEST_TIME, DIFFERENCE;

DROP TABLE IF EXISTS VWEI02.WEBLOG_SESSIONS;
CREATE TABLE VWEI02.WEBLOG_SESSIONS
(
  SESSION_ID				VARCHAR(100)
, REQUEST_TIME				TIMESTAMP
, elb						VARCHAR(100)
, client_port				VARCHAR(50)
, backend_port				VARCHAR(50)
, request_processing_time	DECIMAL(16,6)
, backend_processing_time	DECIMAL(16,6)
, response_processing_time	DECIMAL(16,6)
, elb_status_code			VARCHAR(10)
, backend_status_code		VARCHAR(10)
, received_bytes			BIGINT
, sent_bytes				BIGINT
, request					VARCHAR(256)
, user_agent				VARCHAR(256)
, ssl_cipher				VARCHAR(30)
, ssl_protocol				VARCHAR(20)
)
COMMENT 'Sessionized Weblog with Session IDs.'
STORED AS AVRO;

INSERT OVERWRITE TABLE VWEI02.WEBLOG_SESSIONS
SELECT
  CONCAT_WS('-', S2.CLIENT_PORT, CAST(S2.SESSION AS STRING)) AS SESSION_ID
, L.*
FROM VWEI02.WEBLOG L JOIN VWEI02.WEBLOG_SESSIONIZE_SETP2 S2
ON L.CLIENT_PORT = S2.CLIENT_PORT AND L.REQUEST_TIME = S2.REQUEST_TIME;

CREATE VIEW IF NOT EXISTS VWEI02.AVERAGE_SESSION_TIME_IN_SECONDS AS
SELECT AVG(SESSION_TIME) AS AVERAGE_SESSION_TIME_IN_SECONDS FROM (
SELECT 
SESSION_ID
, UNIX_TIMESTAMP(MAX(REQUEST_TIME)) - UNIX_TIMESTAMP(MIN(REQUEST_TIME)) AS SESSION_TIME
FROM VWEI02.WEBLOG_SESSIONS
GROUP BY SESSION_ID) ST;

CREATE VIEW IF NOT EXISTS VWEI02.UNIQUE_URL_VISITS_PER_SESSION AS
SELECT 
SESSION_ID
, COUNT(DISTINCT request) AS UNIQUE_URL_VISITS_PER_SESSION
FROM VWEI02.WEBLOG_SESSIONS
GROUP BY SESSION_ID;

CREATE VIEW IF NOT EXISTS VWEI02.MOST_ENGAGED_USER AS
SELECT 
  CLIENT_PORT
, SUM(SESSION_TIME) AS TOTAL_SESSION_TIME
, COUNT(SESSION_ID) AS NUM_SESSIONS
FROM
(
  SELECT
	SESSION_ID
  , CLIENT_PORT
  , UNIX_TIMESTAMP(MAX(REQUEST_TIME)) - UNIX_TIMESTAMP(MIN(REQUEST_TIME)) AS SESSION_TIME
  FROM VWEI02.WEBLOG_SESSIONS
  GROUP BY SESSION_ID, CLIENT_PORT
) F
GROUP BY CLIENT_PORT
ORDER BY TOTAL_SESSION_TIME DESC LIMIT 1;
