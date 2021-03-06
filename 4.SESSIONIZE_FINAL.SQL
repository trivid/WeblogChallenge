DROP TABLE IF EXISTS VWEI02.WEBLOG_SESSIONS;
CREATE TABLE VWEI02.WEBLOG_SESSIONS
(
  SESSION_ID_5				VARCHAR(100)
, SESSION_ID_10				VARCHAR(100)
, SESSION_ID_15				VARCHAR(100)
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
  CONCAT_WS('-', S2.CLIENT_PORT, CAST(S2.SESSION_5_MIN AS STRING)) AS SESSION_ID_5
, CONCAT_WS('-', S2.CLIENT_PORT, CAST(S2.SESSION_10_MIN AS STRING)) AS SESSION_ID_10
, CONCAT_WS('-', S2.CLIENT_PORT, CAST(S2.SESSION_15_MIN AS STRING)) AS SESSION_ID_15
, L.*
FROM VWEI02.WEBLOG L JOIN VWEI02.WEBLOG_SESSIONIZE_SETP2 S2
ON L.CLIENT_PORT = S2.CLIENT_PORT AND L.REQUEST_TIME = S2.REQUEST_TIME;
