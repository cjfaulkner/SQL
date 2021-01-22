DECLARE @ObjectName varchar(255) = 'schemaname.TableName'

;WITH CTE_DeleteChain AS
(
	SELECT
		0 AS Level,
		OBJECT_ID(@ObjectName) AS FKTableID,
		@ObjectName AS FKTable
	UNION ALL
	SELECT
		Level + 1 AS Level,
		PARENT_OBJECT_ID AS FK_TableID,
		CONVERT(varchar(255), OBJECT_SCHEMA_NAME(PARENT_OBJECT_ID) + '.' + OBJECT_NAME(PARENT_OBJECT_ID)) AS FKTable
	FROM
		sys.foreign_keys
	INNER JOIN
		CTE_DeleteChain
	ON
		referenced_object_id = FKTableID
), CTE_StatementChain AS
(
	SELECT
		FKTable, MAX(Level) AS Level
	FROM
		CTE_DeleteChain
	GROUP BY
		FKTable
)
SELECT 
	Level,
	CASE WHEN Level = (SELECT MAX(Level) FROM CTE_StatementChain) THEN 'TRUNCATE TABLE ' ELSE 'DELETE FROM ' END + FKTable AS TSQL  
FROM CTE_StatementChain
ORDER BY Level DESC
