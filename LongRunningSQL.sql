SELECT --TOP 100
	CONVERT(varchar(8), DateAdd(SECOND, (qs.last_elapsed_time / 1000000), '00:00:00'), 108) AS LastElapsedTime,
	CONVERT(varchar(8), DateAdd(SECOND, (qs.min_elapsed_time / 1000000), '00:00:00'), 108) AS MinElapsedTime,
	CONVERT(varchar(8), DateAdd(SECOND, (qs.max_elapsed_time / 1000000), '00:00:00'), 108) AS MaxElapsedTime,
	CONVERT(varchar(8), DateAdd(SECOND, ((qs.total_elapsed_time / 1000000) / execution_count), '00:00:00'), 108) as MeanElapsedTime,
	execution_count AS ExecutionCount,
	qs.last_execution_time AS LastExecutionTime,
	st.text AS FullText
FROM
	sys.dm_exec_query_stats qs
CROSS APPLY
	sys.dm_exec_sql_text(qs.sql_handle) st
ORDER BY qs.total_elapsed_time DESC

/*
SELECT DISTINCT
	est.TEXT AS QUERY ,
	Db_name(dbid) AS DBName, 
	eqs.execution_count AS EXEC_CNT,
	eqs.max_elapsed_time AS MAX_ELAPSED_TIME,
	ISNULL(eqs.total_elapsed_time / NULLIF(eqs.execution_count,0), 0) AS AVG_ELAPSED_TIME,
	eqs.creation_time AS CREATION_TIME,
	ISNULL(eqs.execution_count / NULLIF(DATEDIFF(s, eqs.creation_time, GETDATE()),0), 0) AS EXEC_PER_SECOND,
	total_physical_reads AS AGG_PHYSICAL_READS
FROM
	sys.dm_exec_query_stats eqs
CROSS APPLY
	sys.dm_exec_sql_text( eqs.sql_handle ) est
ORDER BY
	eqs.max_elapsed_time DESC

SELECT * FROM sys.dm_exec_sessions

SELECT * FROM sys.dm_external_script_execution_stats
*/