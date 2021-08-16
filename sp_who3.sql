/****************************************************************************************************************************************************
	Title : sp_who3

	Description:
		This gives a more detailled version of sp_who2 which also shows the code being run and can be used to identify blockages.
		If @SPID is set to a non NULL value then it will only look for that SPID or anything the SPID is blocking
		If @UserLogin is set to a non NULL value then it will only look for that login
		If @ShowBlocksOnly is set to a non NULL value then it will only show processes which are blocking or being blocked
		If @DBName is set to a non NULL value then it will only look for that database
		There is code to display the LockObject but it is commented out at the moment 

	Change History:
		Date		Author          Version	Description
		----------	--------------- -------	------------------------------------
		2011-??-??	Chris Faulkner	1.00	Created
sp_who2
select TOP 100 * from V_BATCH
ORDER BY ID DESC

exchangeEvent id=Port157bc560600
WaitType=e_waitPortOpen
waiterType=Coordinator 
nodeId=3
tid=0
ownerActivity=notYetOpened
waiterActivity=waitForAllOwnersToOpen
select * from sys.schemas

144

objectlock lockPartition=0 objid=1667549664 subresource=FULL dbid=39 id=lock2e0342bed80 mode=X associatedObjectId=1667549664
dbcc inputbuffer(131)

****************************************************************************************************************************************************/
-- 100747359 kill 81
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
declare @query nvarchar(max);

DECLARE @AllObjects TABLE (DatabaseID int, ObjectID int, ObjectName varchar(255))

SET @query =
(select 'select ' + CONVERT(VARCHAR(10), d.database_id) + ' as DatabaseID,
				o.object_id,
                ''[' + d.name + '].['' + s.name + ''].['' + o.name + '']'' COLLATE DATABASE_DEFAULT as object_name 
         from ['+ d.name + '].sys.objects o WITH (NOLOCK)
		 INNER JOIN ['+ d.name + '].sys.schemas s WITH (NOLOCK)
		 ON o.schema_id = s.schema_id
		 union all '
  from sys.databases d
  where database_id > 4
  for xml path(''), type).value('.', 'nvarchar(max)');

set @query = left(@query,len(@query)-10);

INSERT INTO @AllObjects (DatabaseID, ObjectID, ObjectName)
execute (@query);

DECLARE @SPID INT = NULL,
	@ShowBlocksOnly bit = NULL,
	@UserLogin varchar(255) = NULL, --'lievrem',
	@DBName varchar(255) = NULL,
	@Host varchar(255) = NULL, --'GVA11V9500065',
	@CommandType varchar(255) = NULL, --'RESTORE DATABASE', -- 'KILLED'
	@Status varchar(255) = NULL, --'runnable'
	@UserOnly bit = 0

SELECT DISTINCT
	ses.session_id AS SPID,
	ses.login_time,
	DB_Name(ses.database_id) AS DBName,
	ses.login_name AS Login,
	ses.host_name AS Host,
	CASE
		WHEN
			wt.blocking_Session_ID = ses.session_id THEN NULL
		ELSE
			wt.blocking_Session_ID
	END AS WaitingFor,
	CONVERT(VARCHAR(255), CONVERT(time, DATEADD(ms, wt.wait_duration_ms, 0)), 108) AS WaitTime,
	ses.open_transaction_count AS open_tran,
	der.command AS CommandType,
	ISNULL(der.status + ' / ', '') + ses.status AS Status,
--	der.percent_complete,
	qtao.ObjectName,
	der.logical_reads,
	der.reads  AS IOReads,
	der.writes  AS IOWrites,
	ses.row_count,
	ses.cpu_time AS CPUTime,
	wt.wait_type,
	wt.resource_type,
--	CASE WHEN ISNULL(wt.ObjectID, 0) <> 0 AND wt.DBID IS NOT NULL THEN
	CASE resource_type
		WHEN 'APPLICATION' THEN
			CASE
				WHEN CHARINDEX('[', wt.resource_description) <> 0 AND CHARINDEX(']', wt.resource_description) <> 0 THEN
					SUBSTRING(LEFT(wt.resource_description, CHARINDEX(']', wt.resource_description) - 1), CHARINDEX('[', wt.resource_description) + 1, 9999)
				WHEN wt.resource_description LIKE 'applicationlock%'
						AND CHARINDEX('hash=', wt.resource_description) <> 0
						AND CHARINDEX(':', wt.resource_description) <> 0 THEN
					SUBSTRING(LEFT(wt.resource_description, CHARINDEX(':', wt.resource_description) - 1), CHARINDEX('hash=', wt.resource_description) + 5, 9999)
			ELSE
				wt.resource_description
			END
		WHEN 'OBJECT' THEN --wt.ObjectID
			COALESCE(wtao.ObjectName, ' ObjectID ' + CONVERT(VARCHAR(50), wt.ObjectID), wt.resource_description)
		WHEN 'DATABASE' THEN
			wtd.name
		ELSE
			wt.resource_description
	END AS WaitResource,
	ses.lock_timeout,
	ses.deadlock_priority,
	der.start_time AS StartTime,
	CASE ses.transaction_isolation_level
		WHEN 0 THEN 'Unspecified' 
		WHEN 1 THEN 'Read Uncommitted' 
		WHEN 2 THEN 'Read Committed' 
		WHEN 3 THEN 'Repeatable' 
		WHEN 4 THEN 'Serializable' 
		WHEN 5 THEN 'Snapshot' 
	END AS transaction_isolation,
 --   CASE WHEN ses.program_name LIKE 'SQLAgent - TSQL JobStep (Job % : Step%' THEN
	--	(	SELECT
	--			'Job : ' + ISNULL(j.name, 'NULL') + ' (Step ' + CONVERT(VARCHAR(10), js.step_id) + ' - ' + ISNULL(js.step_name, 'NULL') + ')'
	--		FROM
	--			msdb.dbo.sysjobs j
	--		INNER JOIN
	--			msdb.dbo.sysjobsteps js
	--		ON
	--			j.job_id = js.job_id
	--		WHERE
	--			j.job_id = CONVERT(uniqueidentifier, CONVERT(varbinary(MAX), CONVERT(varchar(255), LEFT(REPLACE(ses.program_name, 'SQLAgent - TSQL JobStep (Job ', ''), CHARINDEX(':', REPLACE(ses.program_name, 'SQLAgent - TSQL JobStep (Job ', ''))-1)), 1))
	--		AND
	--			js.step_id = CONVERT(int, REPLACE(SUBSTRING(ses.program_name, CHARINDEX(': Step ', ses.program_name) + 7, 1000), ')', ''))
	--	)
	--ELSE
		ses.program_name AS ProgramName,
--	END AS ProgramName,
	CASE   
		WHEN der.[statement_start_offset] > 0 THEN  
			--The start of the active command is not at the beginning of the full command text 
			CASE der.[statement_end_offset]  
				WHEN -1 THEN  SUBSTRING(qt.TEXT, (der.[statement_start_offset]/2) + 1, 2147483647)
              --The end of the full command is also the end of the active statement 
					 
           ELSE   
              --The end of the active statement is not at the end of the full command 
              SUBSTRING(qt.TEXT, (der.[statement_start_offset]/2) + 1, (der.[statement_end_offset] - der.[statement_start_offset])/2)   
        END
     ELSE  
        --1st part of full command is running 
        CASE der.[statement_end_offset]  
           WHEN -1 THEN  
              --The end of the full command is also the end of the active statement 
              RTRIM(LTRIM(qt.[text]))  
           ELSE  
              --The end of the active statement is not at the end of the full command 
              LEFT(qt.TEXT, (der.[statement_end_offset]/2) +2)  
        END  
     END AS [executing statement],
	qt.Text AS [full statement],
	ses.session_id
FROM
	sys.dm_exec_sessions ses WITH (NOLOCK)
LEFT JOIN
	sys.databases dses WITH (NOLOCK)
ON
	dses.database_id = ses.database_id
LEFT JOIN
	sys.dm_exec_requests as der WITH (NOLOCK)
ON 
	ses.session_id = der.session_id
--AND
--	der.command LIKE ISNULL('%' + @CommandType + '%', der.command)
LEFT JOIN
(	SELECT
		wt.session_id,
		wt.blocking_Session_ID,
		--ISNULL(NULLIF(t.resource_description, ''), wt.resource_description) AS resource_description,
		wt.resource_description,
		wt.wait_type,
		t.resource_type,
		wt.wait_duration_ms,
		CASE
			WHEN wt.resource_description LIKE 'objectlock%'
					AND CHARINDEX('associatedObjectId=', wt.resource_description) > 0 THEN
				REPLACE(SUBSTRING(wt.resource_description, CHARINDEX('associatedObjectId=', wt.resource_description), 9999), 'associatedObjectId=', '')
			ELSE
				t.resource_associated_entity_id
		END AS ObjectID,
		CASE
			WHEN wt.resource_description LIKE 'objectlock%'
				AND CHARINDEX('dbid=', wt.resource_description) > 0 THEN
				REPLACE(SUBSTRING(wt.resource_description,
							CHARINDEX('dbid=', wt.resource_description),
							CHARINDEX(' id=', wt.resource_description) - CHARINDEX('dbid=', wt.resource_description)), 'dbid=', '')
			WHEN wt.resource_description LIKE 'databaselock%'
				AND CHARINDEX('dbid=', wt.resource_description) > 0 THEN
				REPLACE(SUBSTRING(wt.resource_description,
							CHARINDEX('dbid=', wt.resource_description),
							CHARINDEX(' lockPartition=', wt.resource_description) - CHARINDEX('dbid=', wt.resource_description)), 'dbid=', '')
			ELSE
				t.resource_database_id
		END AS DBID
	FROM
		sys.dm_os_waiting_tasks wt WITH (NOLOCK)
	LEFT JOIN
		sys.dm_tran_locks t  WITH (NOLOCK)
	ON
		t.lock_owner_address = wt.resource_address
) as wt
ON
	wt.session_id = ses.session_id
LEFT JOIN
	@AllObjects wtao
ON
	wtao.DatabaseID = wt.DBID
AND
	wt.ObjectID = wtao.ObjectID
LEFT JOIN
	sys.databases wtd WITH (NOLOCK)
ON
	wtd.database_id = wt.DBID
OUTER APPLY
	sys.dm_exec_sql_text(der.sql_handle) as qt
LEFT JOIN
	@AllObjects qtao
ON
	qtao.DatabaseID = qt.dbid
AND
	qtao.ObjectID = qt.ObjectID 
LEFT JOIN
	sys.databases qtd WITH (NOLOCK)
ON
	qtd.database_id = qt.dbid
WHERE
(	ses.session_id = ISNULL(@SPID, ses.session_id)
	OR
--	sp.blocked = ISNULL(@SPID, sp.blocked)
--	OR
	wt.blocking_Session_ID = ISNULL(@SPID, wt.blocking_Session_ID)
)
AND
	ses.login_name LIKE ISNULL('%' + @UserLogin + '%', ses.login_name)
AND
	ses.Status LIKE ISNULL('%' + @Status + '%', ses.Status)
--AND
--	LTRIM(RTRIM(ses.host_name)) <> '.'
AND
	ses.session_id <> @@SPID
AND
	dses.name LIKE ISNULL(@DBName, dses.name)
AND
(	@UserOnly = 0
	OR
	ses.is_user_process = 1
)
AND
	ses.host_name = ISNULL(@Host, ses.host_name)
ORDER BY 
	WaitTime DESC,
	ses.session_id,
	WaitingFor

/*
dbcc traceon (3604)
go
dbcc page (18, 951674438, 19)
TAB: 18:951674438:19
KILL 157
exchangeEvent id=Pipe2b6184d8190
WaitType=e_waitPipeGetRow
waiterType=Consumer
nodeId=176
tid=1
ownerActivity=sentData
waiterActivity=needMoreData
merging=true
spilling=false
waitingToClose=false

TAB: 12:1313295263:7
SELECT * FROM sys.objects where object_id = 15675809

SELECT partition_id 
FROM sys.allocation_units 
WHERE  allocation_unit_id= 72057594044940288

SELECT object_name(object_id) as object_name 
FROM sys.partitions 
WHERE partition_id=3297888

dbcc page (12, 90886024, 17)
TAB: 12:90886024:19

39:1:3297888

12:3:5379440
dbcc page (12,3,5379440)

dbcc page (2,3,258816)

SELECT * FROM sys.databases where db_id = 2

select * from sysdatabases

select * from sys.objects where object_id = 1257770467

select * from sysfiles
select * from sysobjects

kill 59

TAB: 10:869693921:0 [COMPILE]
dbcc table (10,0,869693921)
select * from sysobjects where id = 869693921

select * from sysdatabases

select * from sysdatabases
where dbid = 15

select * from ExpedientStaging.sys.objects (NOLOCK)
where id = 951674438

KEY: 27:281474978938880 (324ccfdd4801)
KEY: 12:281474978938880 (948ab4f2aba3)

SELECT o.name, i.name 
FROM sys.partitions p 
JOIN sys.objects o ON p.object_id = o.object_id 
JOIN sys.indexes i ON p.object_id = i.object_id 
AND p.index_id = i.index_id 
WHERE p.hobt_id = 281474978938880


select * from information_schema.tables

select * from sys.sysobjects

select * from syscolumns
where name like '%object%'

select object_name(99)

exchangeEvent
	id=Port2bbdfd27e00
	WaitType=e_waitPortOpen
	waiterType=Coordinator
	nodeId=2 tid=0 ownerActivity=notYetOpened waiterActivity=waitForAllOwnersToOpen

*/	

/*
DECLARE @SPID INT = NULL

SELECT 
	ses.session_id AS SPID,
	ses.status AS Status,
	ses.login_name AS Login,
	ses.host_name AS Host,
	sp.blocked AS BlkBy,
	DB_Name(er.database_id) AS DBName,
	er.command AS CommandType,
	OBJECT_SCHEMA_NAME(qt.objectid, qt.dbid) + '.' + OBJECT_NAME(qt.objectid, qt.dbid) AS ObjectName,
	CONVERT(time(0), getdate() - Last_request_start_time) AS ElapsedTime,
	er.logical_reads + er.reads  AS IOReads,
	er.writes  AS IOWrites,
	er.cpu_time AS CPUTime,
	er.last_wait_type AS LastWaitType,
	er.start_time AS StartTime,
	con.net_transport AS Protocol,
	CASE ses.transaction_isolation_level
		WHEN 0 THEN 'Unspecified' 
		WHEN 1 THEN 'Read Uncommitted' 
		WHEN 2 THEN 'Read Committed' 
		WHEN 3 THEN 'Repeatable' 
		WHEN 4 THEN 'Serializable' 
		WHEN 5 THEN 'Snapshot' 
	END AS transaction_isolation,
	con.num_writes AS ConnectionWrites,
    con.num_reads AS ConnectionReads,
	con.client_net_address AS ClientAddress,
    con.auth_scheme AS Authentication,
    ses.program_name,
	SUBSTRING (qt.text, er.statement_start_offset/2, (CASE
														WHEN er.statement_end_offset = -1 THEN
															LEN(CONVERT(nvarchar(MAX), qt.text)) * 2  
														ELSE
															er.statement_end_offset
													  END - er.statement_start_offset)/2) AS SQLStatement
FROM
	sys.sysprocesses sp
INNER JOIN
	sys.dm_exec_sessions ses
ON
	sp.spid = ses.session_id
LEFT JOIN
	sys.dm_exec_requests er  
ON
	ses.session_id = er.session_id  
LEFT JOIN
	sys.dm_exec_connections con  
ON
	con.session_id = ses.session_id
OUTER APPLY
	sys.dm_exec_sql_text(sp.sql_handle) as qt  
WHERE
	sp.spid = ISNULL(@SPID, sp.spid)
AND
	sp.spid > 50  
AND
	sp.spid <> @@SPID
ORDER BY 
	sp.Blocked DESC,
	sp.spid
*/
/*
sp_configure 'clr enabled', 1
 go
 RECONFIGURE
 go
 sp_configure 'clr enabled'
 go
*/
/*
objectlock lockPartition=22 objid=1534016596 subresource=FULL dbid=18 id=lock54c5e151a00 mode=X associatedObjectId=1534016596

select object_name(1534016596, 18)

*/
/*
 --DeleteStoreRowsAction
 DELETE [storeArchive]
 FROM
 (SELECT
	[Sys_ID]
FROM [ncov].[FACT_DAY_AGG]
) AS [store]
JOIN [ncov_store].[FACT_DAY_AGG] [storeArchive]
ON [store].[Sys_ID] = [storeArchive].[Sys_HeadID]
*/
