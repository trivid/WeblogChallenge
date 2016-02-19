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