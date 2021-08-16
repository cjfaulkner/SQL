/****************************************************************************************************************************************************
	Title : IndexColumns

	Description:
		Columns which appear in multiple indexes 

	Change History:
		Date		Author          Version	Description
		----------	--------------- -------	------------------------------------
		2020-??-??	Chris Faulkner	1.00	Created

****************************************************************************************************************************************************/
WITH CTE_IndexColumns AS
(
	SELECT
		schema_name(o.schema_id) AS ObjectSchema,
		object_name(o.object_id) AS ObjectName,
		i.name AS IndexName,
		c.name AS ColumnName,
		ic.is_included_column AS IsIncluded
	FROM
		sys.indexes i
	INNER JOIN
		sys.index_columns ic
	ON
		ic.object_id = i.object_id
	AND
		ic.index_id = i.index_id
	INNER JOIN
		sys.syscolumns c
	ON
		c.id = i.object_id
	AND
		c.colorder = ic.column_id
	INNER JOIN
		sys.objects o
	ON
		o.object_id = i.object_id
	AND
		o.type_desc <> 'SYSTEM_TABLE'
	WHERE
		i.type_desc <> 'CLUSTERED'
), CTE_MatchIndexes AS
(
	SELECT
		ic1.ObjectSchema,
		ic1.ObjectName,
		ic1.IndexName AS Index1,
		ic2.IndexName AS Index2,
		ic1.ColumnName,
		ic1.IsIncluded AS IncInd1,
		ic2.IsIncluded AS IncInd2
	FROM
		CTE_IndexColumns ic1
	INNER JOIN
		CTE_IndexColumns ic2
	ON
		ic1.ObjectSchema = ic2.ObjectSchema
	AND
		ic1.ObjectName = ic2.ObjectName
	AND
		ic1.ObjectName = ic2.ObjectName
	AND
		ic1.ColumnName = ic2.ColumnName
	WHERE
		ic1.IndexName <> ic2.IndexName
)
	SELECT DISTINCT
		mi.ObjectSchema,
		mi.ObjectName,
		ic1.IndexName AS Index1,
		ic1.ColumnName,
		ic1.IsIncluded AS IncInd1,
		ic2.IndexName AS Index2,
		ic2.ColumnName,
		ic2.IsIncluded AS IncInd2
	FROM
		CTE_MatchIndexes mi
	FULL JOIN
		CTE_IndexColumns ic1
	ON
		ic1.ObjectSchema = mi.ObjectSchema
	AND	
		ic1.ObjectName = mi.ObjectName
	AND
		ic1.IndexName = mi.Index1
	FULL JOIN
		CTE_IndexColumns ic2
	ON
		ic2.ObjectSchema = mi.ObjectSchema
	AND	
		ic2.ObjectName = mi.ObjectName
	AND
		ic2.IndexName = mi.Index2
	WHERE
		ic1.IndexName <> ic2.IndexName
	AND
		ISNULL(ic1.ColumnName, ic2.ColumnName) = ISNULL(ic2.ColumnName, ic1.ColumnName)
