--SELECT [t].[name] AS [Table], [p].[partition_number] AS [Partition],
--    [p].[data_compression_desc] AS [Compression]
--FROM [sys].[partitions] AS [p]
--INNER JOIN sys.tables AS [t] ON [t].[object_id] = [p].[object_id]
--WHERE [p].[index_id] in (0,1)

SELECT
	s.name AS [Schema],
	[t].[name] AS [Table],
	[i].[name] AS [Index],  
    [p].[partition_number] AS [Partition],
    [p].[data_compression_desc] AS [Compression],
	i.type_desc AS [Index Type],
	si.rows  AS [Index Rows],
	'ALTER INDEX [' + i.name + '] ON [' + s.name + '].[' + t.name + '] REBUILD  WITH (DATA_COMPRESSION=ROW)' AS RebuildSQL
FROM [sys].[partitions] AS [p] WITH (NOLOCK)
INNER JOIN sys.tables AS [t] WITH (NOLOCK)
ON [t].[object_id] = [p].[object_id]
INNER JOIN sys.schemas AS s WITH (NOLOCK)
ON
	t.schema_id = s.schema_id
LEFT JOIN sys.indexes AS [i] WITH (NOLOCK)
	INNER JOIN sys.sysindexes si WITH (NOLOCK)
	ON
		i.object_id = si.id
	AND
		i.index_id = si.indid
	--INNER JOIN (VALUES	(0, 'Heap'),
	--					(1, 'Clustered rowstore (B-tree)'),
	--					(2, 'Nonclustered rowstore (B-tree)'),
	--					(3, 'XML'),
	--					(4, 'Spatial'),
	--					(5, 'Clustered columnstore index.'),
	--					(6, 'Nonclustered columnstore index'),
	--					(7,  'Nonclustered hash index') t(id,name)
	--ON
	--	i.type = t.id
ON [i].[object_id] = [p].[object_id] AND [i].[index_id] = [p].[index_id]
WHERE p.data_compression_desc <> 'ROW'
AND i.type_desc <> 'HEAP'
AND si.rows <= 10000
ORDER BY si.rows DESC
