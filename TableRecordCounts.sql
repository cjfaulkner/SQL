SET STATISTICS TIME OFF
SET STATISTICS IO OFF
GO
/*
DECLARE @StartTime DATETIME = GETDATE()
DECLARE @SQL VARCHAR(MAX)
DECLARE @Results TABLE (TableName VARCHAR(255), RecordCount INT)

DECLARE csr_SQL CURSOR LOCAL FORWARD_ONLY READ_ONLY FOR
SELECT 'SELECT ''' + TABLE_SCHEMA + '.' + TABLE_NAME + ''' AS TableName, COUNT(*) AS RecordCount FROM ' + TABLE_SCHEMA + '.' + TABLE_NAME ' WITH (NOLOCK)'
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME

OPEN csr_SQL

FETCH NEXT
FROM csr_SQL
INTO @SQL

WHILE @@FETCH_STATUS = 0
BEGIN

	INSERT INTO @Results (TableName, RecordCount)
	EXEC(@SQL)

	FETCH NEXT
	FROM csr_SQL
	INTO @SQL
END

CLOSE csr_SQL
DEALLOCATE csr_SQL

SELECT * FROM @Results
ORDER BY RecordCount DESC

SELECT DATEDIFF(SECOND, @StartTime, GETDATE())
*/
GO
DECLARE @LowRowCount INTEGER = 1000000 

--DECLARE @StartTime DATETIME = GETDATE()
;WITH CTE_TableStats AS
(
    SELECT
        ps.object_id,
        SUM (ps.reserved_page_count) AS ReservedPages,
        SUM (ps.used_page_count) AS UsedPages,
        SUM (
            CASE
                WHEN (ps.index_id < 2) THEN
					(ps.in_row_data_page_count + ps.lob_used_page_count + ps.row_overflow_used_page_count)
                ELSE 0
            END
        ) AS Pages,
        SUM (
            CASE
                WHEN (ps.index_id < 2) THEN row_count
                ELSE 0
            END
            ) AS TableRowCount
	FROM
		sys.dm_db_partition_stats ps WITH (NOLOCK)
    GROUP BY
        object_id
)
SELECT
	s.name AS SchemaName,
	t.name AS TableName,
	ts.TableRowCount,
	t.max_column_id_used AS ColumnCount,
	CONVERT (decimal(15,3), (ts.ReservedPages * 8.0) / 1024.0) AS ReservedSize_MB,
	CONVERT (decimal(15,3), (ts.ReservedPages * 8.0)) AS ReservedSize_KB,
	CONVERT (decimal(15,3), (ts.UsedPages * 8.0) / 1024.0) AS UsedSize_MB,
	CONVERT (decimal(15,3), (ts.UsedPages * 8.0)) AS UsedSize_KB
FROM
	sys.tables t WITH (NOLOCK)
INNER JOIN
	CTE_TableStats ts
ON
	t.object_id = ts.object_id
INNER JOIN
	sys.schemas s WITH (NOLOCK)
ON
	s.schema_id = t.schema_id
WHERE
	t.Type = 'U'
AND
	ts.TableRowCount >= @LowRowCount
ORDER BY
--	s.name,
	ts.TableRowCount DESC




--SELECT DATEDIFF(SECOND, @StartTime, GETDATE())

/*
SELECT Sys_CommitRequestUtc FROM BATCH WHERE ID =
(
SELECT MAX(Sys_BatchID)
FROM mort_store.RAW_EUROSTAT WITH (NOLOCK)
)


*/
