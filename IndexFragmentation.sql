SELECT dbschemas.[name] as 'Schema',
dbtables.[name] as 'Table',
dbindexes.[name] as 'Index',
indexstats.avg_fragmentation_in_percent,
indexstats.page_count
FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) AS indexstats
INNER JOIN sys.tables dbtables on dbtables.[object_id] = indexstats.[object_id]
INNER JOIN sys.schemas dbschemas on dbtables.[schema_id] = dbschemas.[schema_id]
INNER JOIN sys.indexes AS dbindexes ON dbindexes.[object_id] = indexstats.[object_id]
AND indexstats.index_id = dbindexes.index_id
WHERE indexstats.database_id = DB_ID()
AND dbschemas.[name] LIKE 'WIISE%'
ORDER BY indexstats.avg_fragmentation_in_percent desc

/*
ALTER INDEX 
ON REF_POPULATIONS REBUILD




ALTER INDEX PK_NCOV_LINELIST
ON ncov_store.NCOV_LINELIST REBUILD

ALTER INDEX IX__Sys_BatchID
ON ncov_store.NCOV_LINELIST REBUILD

ALTER INDEX IX__Sys_RowTitle
ON ncov_store.NCOV_LINELIST REBUILD

*/

--UPDATE STATISTICS ncov_store.NCOV_LINELIST