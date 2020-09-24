USE CJFTest;
GO
DECLARE @StartTime datetime2
DECLARE @Change1Time datetime2
DECLARE @Change2Time datetime2
DECLARE @Change3Time datetime2

IF OBJECT_ID('CountryTemporal') IS NOT NULL
BEGIN
	ALTER TABLE CountryTemporal
	SET (SYSTEM_VERSIONING = OFF)

	DROP TABLE CountryTemporal;

	DROP TABLE IF EXISTS dbo.CountryTemporalHistory;
END


CREATE TABLE CountryTemporal
(	ID			INT NOT NULL IDENTITY(1,1) PRIMARY KEY CLUSTERED,
	ISO3Code	char(3),
	CountryName	varchar(50),
	[ValidFrom] datetime2 GENERATED ALWAYS AS ROW START HIDDEN,
	[ValidTo] datetime2 GENERATED ALWAYS AS ROW END HIDDEN,
	PERIOD FOR SYSTEM_TIME (ValidFrom, ValidTo)
 )
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.CountryTemporalHistory));

CREATE UNIQUE INDEX UQ_CountryTemporal_Iso3Code
ON CountryTemporal (ISO3Code)

SET @StartTime = GETUTCDATE()

INSERT INTO CountryTemporal (ISO3Code, CountryName) VALUES
('CXR', 'Christmas Island'),
('NRU', 'Nauru'),
('KNA', 'Saint Kitts and Nevis')

SELECT CONVERT(varchar(8), @StartTime, 114) AS StartTime
SELECT 'CountryTemporal' AS TableName
SELECT * FROM CountryTemporal
SELECT 'CountryTemporalHistory' AS TableName
SELECT * FROM CountryTemporalHistory



-- Wait 5 seconds
WAITFOR DELAY '00:00:05'

SET @Change1Time = GETUTCDATE()

UPDATE CountryTemporal
SET CountryName = 'St Kitts and Nevis'
WHERE ISO3Code = 'KNA'


SELECT 'SET CountryName = ''St Kitts and Nevis'' WHERE ISO3Code = ''KNA''' AS SQLRun

SELECT
	CONVERT(varchar(8), @StartTime, 114) AS StartTime,
	CONVERT(varchar(8), @Change1Time,114) AS Change1Time

SELECT 'CountryTemporal' AS TableName
SELECT * FROM CountryTemporal
SELECT 'CountryTemporalHistory' AS TableName
SELECT * FROM CountryTemporalHistory

-- Wait 5 seconds
WAITFOR DELAY '00:00:05'
SET @Change2Time = GETUTCDATE()

UPDATE CountryTemporal
SET CountryName = 'Christmas Is.'
WHERE ISO3Code = 'CXR'

SELECT 'CountryName = ''Christmas Is.'' WHERE ISO3Code = ''CXR''' AS SQLRun

SELECT
	CONVERT(varchar(8), @StartTime, 114) AS StartTime,
	CONVERT(varchar(8), @Change1Time,114) AS Change1Time,
	CONVERT(varchar(8), @Change2Time,114) AS Change2Time

SELECT 'CountryTemporal' AS TableName
SELECT * FROM CountryTemporal
SELECT 'CountryTemporalHistory' AS TableName
SELECT * FROM CountryTemporalHistory

-- Wait 5 seconds
WAITFOR DELAY '00:00:05'
SET @Change3Time = GETUTCDATE()

UPDATE CountryTemporal
SET CountryName = 'Christmas Is.'
WHERE ISO3Code = 'CXR'

SELECT 'CountryName = ''Christmas Is.'' WHERE ISO3Code = ''CXR''' AS SQLRun

SELECT
	CONVERT(varchar(8), @StartTime, 114) AS StartTime,
	CONVERT(varchar(8), @Change1Time,114) AS Change1Time,
	CONVERT(varchar(8), @Change2Time,114) AS Change2Time,
	CONVERT(varchar(8), @Change3Time,114) AS Change3Time,
	'Rerun Last Update' AS Explanation

SELECT 'CountryTemporal' AS TableName
SELECT * FROM CountryTemporal
SELECT 'CountryTemporalHistory' AS TableName
SELECT * FROM CountryTemporalHistory

DECLARE @TimeTemp datetime2

SELECT 'Data From Start To Finish on CountryTemporal'
SELECT * FROM CountryTemporal FOR SYSTEM_TIME BETWEEN @StartTime AND @Change3Time

SET @TimeTemp = dateadd(second, 1, @Change1Time)

SELECT 'Data From Start To Change1Time + 1 second on CountryTemporal'
SELECT * FROM CountryTemporal FOR SYSTEM_TIME BETWEEN @StartTime AND @TimeTemp

SET @TimeTemp = dateadd(second, 1, @Change2Time)

SELECT 'Data From Start To Change2Time + 1 second on CountryTemporal'
SELECT * FROM CountryTemporal FOR SYSTEM_TIME BETWEEN @StartTime AND @TimeTemp

SELECT *
FROM
	CountryTemporal
--	FOR SYSTEM_TIME BETWEEN @StartTime AND @Change3Time ct




;WITH CTE_TimeLoop AS
(
	SELECT
		@StartTime AS RecordTime
	UNION ALL
	SELECT
		dateadd(second, 1, RecordTime) AS RecordTime
	FROM
		CTE_TimeLoop
	WHERE
		RecordTime < dateadd(second, 5, @Change3Time)
)
SELECT
	CONVERT(varchar(8), tl.RecordTime, 114) AS RecordTime,
	--ct.ISO3Code,
	--ct.CountryName
	ct.*
FROM
	CTE_TimeLoop tl
INNER JOIN
	CountryTemporal
	FOR SYSTEM_TIME BETWEEN @StartTime AND  @Change3Time ct
ON
	tl.RecordTime BETWEEN ct.ValidFrom AND ct.ValidTo

	
