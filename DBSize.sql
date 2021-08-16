DROP TABLE IF EXISTS #DBStats
DECLARE @DBTotalSize_MB float

;WITH CTE_TableStats AS
(
    SELECT
        object_id,
        object_schema_name(object_id) AS SchemaName,
		object_name(object_id) AS TableName,
        SUM (reserved_page_count) AS ReservedPages,
        SUM (used_page_count) AS UsedPages,
        SUM (
            CASE
                WHEN (index_id < 2) THEN (in_row_data_page_count + lob_used_page_count + row_overflow_used_page_count)
                ELSE 0
            END
        ) AS Pages,
        SUM (
            CASE
                WHEN (index_id < 2) THEN row_count
                ELSE 0
            END
            ) AS TableRowCount
	FROM sys.dm_db_partition_stats ps WITH (NOLOCK)
    GROUP BY
        object_id
)
SELECT
	ts.SchemaName,
    ts.TableName,
    ts.TableRowCount,
	CONVERT (decimal(15,3), (ts.ReservedPages * 8.0) / 1024.0) AS ReservedSize_MB,
	CONVERT (decimal(15,3), (ts.ReservedPages * 8.0)) AS ReservedSize_KB,
	CONVERT (decimal(15,3), (ts.UsedPages * 8.0) / 1024.0) AS UsedSize_MB,
	CONVERT (decimal(15,3), (ts.UsedPages * 8.0)) AS UsedSize_KB
INTO #DBStats
FROM
    CTE_TableStats ts
INNER JOIN
    sys.objects o WITH (NOLOCK)
ON
    o.object_id = ts.object_id
ORDER BY
    ts.SchemaName,
    ts.TableName

SELECT
	@DBTotalSize_MB = SUM(ReservedSize_MB)
FROM
	#DBStats

SELECT
	SchemaName,
	SUM(sch.ReservedSize_MB) AS SchemaTotal_MB,
	(SUM(sch.ReservedSize_MB) * 100) / @DBTotalSize_MB AS [Schema % of DB]
FROM
	#DBStats sch
GROUP BY
	SchemaName
ORDER BY 2 DESC,1

SELECT
	SchemaName,
    TableName,
    TableRowCount,
    ReservedSize_MB,
	(ReservedSize_MB * 100) / @DBTotalSize_MB AS [Table % of DB]
FROM #DBStats
ORDER BY 4 DESC,3,1,2
