/****************************************************************************************************************************************************
	Title : TableBuilder

	Description:
		Creates an exact copy of a table in the staging schema  

	Change History:
		Date		Author          Version	Description
		----------	--------------- -------	------------------------------------
		2011-??-??	Chris Faulkner	1.00	Created

****************************************************************************************************************************************************/

DECLARE @FullTableName VARCHAR(255) = 'supply_chain_lax.FACT_OXYGEN_115935_with_issues'
DECLARE @TargetSchema VARCHAR(255) = 'staging'
DECLARE @SQL VARCHAR(MAX), @ColumnNames VARCHAR(MAX) = NULL

SET @SQL = 'IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name=''' + @TargetSchema + ''')
BEGIN
	EXEC(''CREATE SCHEMA ' + @TargetSchema + ''')
END;
GO
'

DECLARE
	@DatabaseName VARCHAR(50) = NULL,
	@TableSchema VARCHAR(50) = NULL,
	@TableName	VARCHAR(50) = NULL,
	@CreateScript varchar(MAX) = NULL,
	@Debug bit = 0,
	@LastDotPlace int

	SET @FullTableName = REPLACE(REPLACE(@FullTableName, '[', ''), ']', '')
	SET @LastDotPlace = LEN(@FullTableName) - CHARINDEX('.', REVERSE(@FullTableName)) + 1

	IF @LastDotPlace <> LEN(@FullTableName) + 1
	BEGIN
		SET @TableSchema = LEFT(@FullTableName, @LastDotPlace - 1)
		SET @TableName = SUBSTRING(@FullTableName, @LastDotPlace + 1, 9999)

		SET @LastDotPlace = LEN(@TableSchema) - CHARINDEX('.', REVERSE(@TableSchema)) + 1

		IF @LastDotPlace <> LEN(@TableSchema) + 1
		BEGIN
			SET @DataBaseName = LEFT(@TableSchema, @LastDotPlace - 1)
			SET @TableSchema = SUBSTRING(@TableSchema, @LastDotPlace + 1, 9999)
		END
	END
	ELSE
	BEGIN
		SELECT
			@TableName = @FullTableName,
			@TableSchema = 'dbo'
	END

IF @Debug = 1
	SELECT @TableName AS '@TableName', @TableSchema AS '@TableSchema'


DECLARE @SourceTableName varchar(MAX)

SET @SQL = @SQL + 'IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = ''' + @TargetSchema +
''' AND TABLE_NAME = ''' + @TableName + ''' AND TABLE_TYPE = ''BASE TABLE'')
BEGIN
	DROP TABLE [' + @TargetSchema + '].[' + @TableName + ']
END;
GO
'

SET @SQL = @SQL + 'CREATE TABLE [' + @TargetSchema + '].[' + @TableName + ']
( '

SELECT @ColumnNames = ISNULL(@ColumnNames + ',', '') + '[' + COLUMN_NAME + '] ' + DATA_TYPE +
ISNULL('(' +
		CASE
			WHEN CHARACTER_MAXIMUM_LENGTH = -1 THEN 'MAX'
			ELSE
				ISNULL(CONVERT(VARCHAR(8), CHARACTER_MAXIMUM_LENGTH),
                    CASE
						WHEN ISNULL(NUMERIC_SCALE, 0) <> 0 THEN
							CONVERT(VARCHAR(8), NUMERIC_PRECISION) + ',' + CONVERT(VARCHAR(8), NUMERIC_SCALE)
						ELSE
							NULL
					END)
			END + ') ', ' ') +
			CASE IS_NULLABLE 
				WHEN 'YES' THEN ' NULL '
				ELSE 'NOT NULL'
			END + '
'
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME= @TableName
AND TABLE_SCHEMA = @TableSchema
ORDER BY ORDINAL_POSITION

SET @SQL = @SQL + @ColumnNames + ')
GO
'

IF @Debug = 1
	SELECT @ColumnNames AS '@ColumnNames'


;WITH CTE_IndexColumns AS
(
	SELECT 
		i.name as IndexName,
		CASE WHEN i.is_unique = 1 THEN ' UNIQUE ' ELSE '' END + i.type_desc AS IndexType,
		STUFF( (SELECT ',' + c.name
				FROM sys.columns c
				INNER JOIN sys.index_columns ic
				ON c.object_id = ic.OBJECT_ID
				AND c.column_id = ic.column_id
				AND ic.is_included_column = 0
				WHERE ic.object_id = i.object_id
				AND	ic.index_id = i.index_id
				ORDER BY ic.key_ordinal
				FOR XML PATH ('')), 1, 1, '') AS IndexColumns,
		STUFF( (SELECT ',' + c.name
				FROM sys.columns c
				INNER JOIN sys.index_columns ic
				ON c.object_id = ic.OBJECT_ID
				AND c.column_id = ic.column_id
				AND ic.is_included_column = 1
				WHERE ic.object_id = i.object_id
				AND	ic.index_id = i.index_id
				ORDER BY ic.key_ordinal
				FOR XML PATH ('')), 1, 1, '') AS IncludedColumns
	FROM
		sys.indexes i
	WHERE
		object_name(i.object_id) = @TableName
	AND
		object_schema_name(i.object_id) = @TableSchema
	AND
		i.is_primary_key = 0
	AND
		i.is_unique_constraint = 0
)
SELECT @SQL = @SQL + ISNULL('
	CREATE ' + IndexType + ' INDEX ' + ic.IndexName + ' ' +
	' ON [' + @TargetSchema + '].[' + @TableName + '] (' + ic.IndexColumns + ')' +
	ISNULL(' INCLUDE (' + ic.IncludedColumns + ')', ''), '')
FROM 
	CTE_IndexColumns ic

IF @Debug = 1
	SELECT @SQL AS 'Indexes added'

;WITH CTE_IndexColumns AS
(
	SELECT 
		i.name as IndexName,
		i.type_desc AS IndexType,
		STUFF( (SELECT ',' + c.name
				FROM sys.columns c
				INNER JOIN sys.index_columns ic
				ON c.object_id = ic.OBJECT_ID
				AND c.column_id = ic.column_id
				AND ic.is_included_column = 0
				WHERE ic.object_id = i.object_id
				AND	ic.index_id = i.index_id
				ORDER BY ic.key_ordinal
				FOR XML PATH ('')), 1, 1, '') AS IndexColumns
	FROM
		sys.indexes i
	WHERE
		object_name(i.object_id) = @TableName
	AND
		object_schema_name(i.object_id) = @TableSchema
	AND
		i.is_primary_key = 1
	AND
		i.is_unique_constraint = 0
)
SELECT @SQL = @SQL + ISNULL('ALTER TABLE [' + @TargetSchema + '].[' + @TableName + '] ADD CONSTRAINT ' + ic.IndexName + 
	' PRIMARY KEY ' + ic.IndexType +
	' (' + ic.IndexColumns + ')', '')
FROM 
	CTE_IndexColumns ic

IF @Debug = 1
	SELECT @SQL AS 'PK added'

;WITH CTE_FKCOLS AS
(
	SELECT
		fk.name AS FK_Name,
		fk.parent_object_id,
		fk.referenced_object_id,
		'[' + cc.name + ']' AS ConstraintColumn,
		'[' + rc.name + ']' AS ReferencedColumn
	FROM
		sys.foreign_keys fk
	INNER JOIN
		sys.foreign_key_columns fkc
	ON
		fk.object_id = fkc.constraint_object_id
	AND
		fkc.parent_object_id = fk.parent_object_id
	AND
		fkc.referenced_object_id = fk.referenced_object_id
	INNER JOIN
		sys.columns cc
	ON
		cc.object_id = fkc.parent_object_id
	AND
		cc.column_id = fkc.parent_column_id
	INNER JOIN
		sys.columns rc
	ON
		rc.object_id = fkc.referenced_object_id
	AND
		rc.column_id = fkc.referenced_column_id
	WHERE
		object_name(fk.parent_object_id) = @TableName
	AND
		object_schema_name(fk.parent_object_id) = @TableSchema

), CTE_FK_COLLIST AS
(
SELECT
	fkc.FK_Name,
	fkc.parent_object_id,
	fkc.referenced_object_id,
	STUFF(
			(SELECT ',' + fkcc.ConstraintColumn
			FROM CTE_FKCOLS fkcc
			WHERE fkcc.FK_Name = fkc.FK_NAME
			AND fkcc.parent_object_id = fkc.parent_object_id
			AND fkcc.referenced_object_id = fkcc.referenced_object_id
			AND fkcc.ReferencedColumn = fkc.ReferencedColumn
			FOR XML PATH ('')), 1, 1, '') AS ConstraintColumns,
	STUFF(
			(SELECT ',' + fkcc.ReferencedColumn 
			FROM CTE_FKCOLS fkcc
			WHERE fkcc.FK_Name = fkc.FK_Name
			AND fkcc.parent_object_id = fkc.parent_object_id
			AND fkcc.referenced_object_id = fkcc.referenced_object_id
			AND fkcc.ConstraintColumn = fkc.ConstraintColumn
			FOR XML PATH ('')), 1, 1, '') AS ReferencedColumns
	FROM
		CTE_FKCOLS fkc
)
SELECT @SQL = @SQL + 
	ISNULL('ALTER TABLE [' + @TargetSchema + '].[' + @TableName + '] ADD CONSTRAINT [' + fk.FK_Name + ']' + 
	' FOREIGN KEY (' + fk.ConstraintColumns + ')' +
	' REFERENCES [' + object_schema_name(fk.referenced_object_id) + '].[' + object_name(fk.referenced_object_id) + '] ' +
	'(' + fk.ReferencedColumns + ')', '') + '
'
FROM CTE_FK_COLLIST fk

IF @Debug = 1
	SELECT @SQL AS 'FK added'

SELECT @SQL = @SQL + 
	ISNULL('ALTER TABLE [' + @TargetSchema + '].[' + @TableName + '] ADD CONSTRAINT [' + dc.Name + ']' + 
	' DEFAULT ' + dc.definition + ' FOR [' + c.name + ']
', '')
FROM
	sys.default_constraints dc
INNER JOIN
	sys.columns c
ON
	c.object_id = dc.parent_object_id
AND
	c.column_id = dc.parent_column_id
WHERE
	object_name(dc.parent_object_id) = @TableName
AND
	object_schema_name(dc.parent_object_id) = @TableSchema

SELECT @SQL = @SQL + 
	ISNULL('ALTER TABLE [' + @TargetSchema + '].[' + @TableName + '] ADD CONSTRAINT [' + cc.Name + ']' + 
	' CHECK ' + cc.definition + '
', '')
FROM
	sys.check_constraints cc
WHERE
	object_name(cc.parent_object_id) = @TableName
AND
	object_schema_name(cc.parent_object_id) = @TableSchema

SELECT @SQL = @SQL + 'EXEC sys.sp_addextendedproperty @name=N''' + lep.name +
	''', @value=N''' + CONVERT(varchar(255), lep.value) +
	''', @level0type=N''SCHEMA'',@level0name=N''' + @TargetSchema + ''',
	@level1type=N''TABLE'',@level1name=N''' + @TableName + '''' +
	CASE
		WHEN t.a IS NOT NULL THEN ',@level2type=N''' + lep.objtype + ''',@level2name=N''' + lep.objname +''''
	ELSE
		''
	END + '
'
FROM (VALUES ('COLUMN'), ('CONSTRAINT'), ('EVENT NOTIFICATION'), ('INDEX'), ('PARAMETER'), ('TRIGGER'), (NULL)) t(a)
CROSS APPLY
	fn_listextendedproperty(NULL, 'SCHEMA', @TableSchema, 'TABLE', @TableName, t.a, NULL) lep




SET @SQL = @SQL + '
'

SELECT @SQL
