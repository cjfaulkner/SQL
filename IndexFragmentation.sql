DROP TABLE IF EXISTS #IndexBuild

DECLARE @SQL VARCHAR(MAX)
DECLARE @TableName VARCHAR(255)
DECLARE @SchemaName VARCHAR(255)
DECLARE @IndexName VARCHAR(255)
DECLARE @FragThreshold float = 80 -- To stop rebuilds set this to 110
DECLARE @SchemaFilter VARCHAR(255) = 'wiise_store'

SELECT
	dbschemas.[name] as 'SchemaName',
	dbtables.[name] as 'TableName',
	dbindexes.[name] as 'IndexName',
	indexstats.avg_fragmentation_in_percent,
	indexstats.page_count
INTO #IndexBuild
FROM
	sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS indexstats
INNER JOIN
	sys.tables dbtables
ON
	dbtables.[object_id] = indexstats.[object_id]
INNER JOIN
	sys.schemas dbschemas
ON
	dbtables.[schema_id] = dbschemas.[schema_id]
INNER JOIN
	sys.indexes AS dbindexes
ON
	dbindexes.[object_id] = indexstats.[object_id]
AND
	indexstats.index_id = dbindexes.index_id
WHERE
	indexstats.database_id = DB_ID()
AND
	dbschemas.[name] LIKE '%' + ISNULL(@SchemaFilter, '') + '%'
AND
	indexstats.avg_fragmentation_in_percent >= @FragThreshold
ORDER BY
	indexstats.avg_fragmentation_in_percent DESC

SELECT * FROM #IndexBuild

WHILE (SELECT COUNT(*) FROM #IndexBuild) > 0
BEGIN
	SELECT TOP 1
		@TableName = TableName,
		@SchemaName = SchemaName,
		@IndexName = IndexName	
	FROM
		#IndexBuild
	
	SET @SQL = 'ALTER INDEX ' + @IndexName + ' ON ' + @SchemaName + '.' + @TableName + ' REBUILD'

	RAISERROR(@SQL, 0, 0) WITH NOWAIT

	EXEC (@SQL)

	DELETE
	FROM
		#IndexBuild
	WHERE
		TableName = @TableName
	AND
		SchemaName = @SchemaName
	AND
		IndexName = @IndexName	
END

--UPDATE STATISTICS ncov_store.NCOV_LINELIST