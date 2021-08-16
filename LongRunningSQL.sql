SELECT TOP 100
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
WHERE
	st.objectid IS NULL
ORDER BY 4 DESC
