/****************************************************************************************************************************************************
	Title : Dependecies

	Description:
		Which table is called from a view which is called from a view

	Change History:
		Date		Author          Version	Description
		----------	--------------- -------	------------------------------------
		2011-??-??	Chris Faulkner	1.00	Created

****************************************************************************************************************************************************/
WITH CTE_VIEW_TABLE_USAGE AS
(
	SELECT
		OBJECT_SCHEMA_NAME(sed.referencing_id) AS VIEW_SCHEMA,
		OBJECT_NAME(sed.referencing_id) AS VIEW_NAME,
		t.TABLE_SCHEMA,
		t.TABLE_NAME,
		t.TABLE_TYPE
	FROM
		sys.sql_expression_dependencies sed WITH (NOLOCK)
	INNER JOIN
		INFORMATION_SCHEMA.TABLES t WITH (NOLOCK)
	ON
		sed.referenced_schema_name = t.TABLE_SCHEMA
	AND
		sed.referenced_entity_name = t.TABLE_NAME
	WHERE
		sed.referencing_id <> sed.referenced_id

),CTE_ViewTables AS
(
	SELECT 
		1 AS Depth,
		vtu.VIEW_SCHEMA,
		vtu.VIEW_NAME,
		vtu.TABLE_SCHEMA,
		vtu.TABLE_NAME,
		vtu.TABLE_TYPE
	FROM
		CTE_VIEW_TABLE_USAGE vtu
	UNION ALL
	SELECT 
		Depth + 1 AS Depth,
		vt.VIEW_SCHEMA,
		vt.VIEW_NAME,
		vtu.TABLE_SCHEMA,
		vtu.TABLE_NAME,
		vtu.TABLE_TYPE
	FROM
		CTE_ViewTables vt
	INNER JOIN
		CTE_VIEW_TABLE_USAGE vtu
	ON
		vtu.VIEW_SCHEMA = vt.TABLE_SCHEMA
	AND
		vtu.VIEW_NAME = vt.TABLE_NAME
)
SELECT DISTINCT
	VIEW_SCHEMA,
	VIEW_NAME,
	MAX(Depth) AS Depth,
	TABLE_SCHEMA,
	TABLE_NAME
FROM
	CTE_ViewTables vt
WHERE
	vt.TABLE_TYPE = 'BASE TABLE'
GROUP BY
	VIEW_SCHEMA,
	VIEW_NAME,
	TABLE_SCHEMA,
	TABLE_NAME
ORDER BY
	VIEW_SCHEMA, VIEW_NAME, TABLE_SCHEMA, TABLE_NAME