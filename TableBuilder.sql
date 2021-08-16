/****************************************************************************************************************************************************
	Title : TableBuilder

	Description:
		Creates an exact copy of a table in the staging schema  

	Change History:
		Date		Author          Version	Description
		----------	--------------- -------	------------------------------------
		2011-??-??	Chris Faulkner	1.00	Created

****************************************************************************************************************************************************/

DECLARE @FullTableName VARCHAR(255) = 'tableName'
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
	@LastDotPlace int

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

SELECT @ColumnNames = ISNULL(@ColumnNames + ',', '') + COLUMN_NAME + ' ' + DATA_TYPE +
ISNULL('(' +
			ISNULL(CONVERT(VARCHAR(8), CHARACTER_MAXIMUM_LENGTH),
                    CASE
						WHEN ISNULL(NUMERIC_SCALE, 0) <> 0 THEN
							CONVERT(VARCHAR(8), NUMERIC_PRECISION) + ',' + CONVERT(VARCHAR(8), NUMERIC_SCALE)
						ELSE
							NULL
						END) + ') ', ' ') +
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

;WITH CTE_IndexColumnBuilder AS
(	SELECT
		ic.object_id,
		ic.index_id,
		CONVERT(VARCHAR(MAX), c.name) AS NonIncludedColumnList,
		CONVERT(VARCHAR(MAX), NULL) AS IncludedColumnList,
		ic.index_column_id
	FROM
		sys.indexes i
	INNER JOIN
		sys.index_columns ic
	ON
		ic.object_id = i.object_id
	AND
		ic.index_id = i.index_id
	INNER JOIN
		sys.columns c
	ON
		ic.object_id = c.object_id
	AND
		ic.column_id = c.column_id
	WHERE
		ic.index_column_id = 1
	AND
		i.is_primary_key = 0
	AND
		i.is_unique_constraint = 0
	UNION ALL
	SELECT
		nic.object_id,
		nic.index_id,
		CONVERT(VARCHAR(MAX), NonIncludedColumnList + CASE WHEN is_included_column = 0 THEN ',' + c.name ELSE '' END) AS NonIncludedColumnList,
		CONVERT(VARCHAR(MAX), ISNULL(IncludedColumnList + ',', '') + CASE WHEN is_included_column = 1 THEN c.name ELSE '' END) AS IncludedColumnList,
		ic.index_column_id
	FROM
		CTE_IndexColumnBuilder nic
	INNER JOIN
		sys.index_columns ic
	ON
		nic.object_id = ic.object_id
	AND
		nic.index_id = ic.index_id
	INNER JOIN
		sys.columns c
	ON
		ic.object_id = c.object_id
	AND
		ic.column_id = c.column_id
	WHERE
		ic.index_column_id = nic.index_column_id + 1
), CTE_IndexColumnBuilderMax AS
(
	SELECT
		object_id,
		index_id,
		MAX(index_column_id) AS index_column_id
	FROM
		CTE_IndexColumnBuilder
	GROUP BY
		object_id,
		index_id

), CTE_IndexColumns AS
(
	SELECT
		nicb.object_id,
		nicb.index_id,
		i.name COLLATE DATABASE_DEFAULT AS IndexName,
		nicb.NonIncludedColumnList,
		nicb.IncludedColumnList,
		i.is_unique,
		i.type_desc COLLATE DATABASE_DEFAULT AS IndexType
	FROM
		CTE_IndexColumnBuilder nicb
	INNER JOIN
		CTE_IndexColumnBuilderMax nicbm
	ON
		nicb.object_id = nicbm.object_id
	AND
		nicb.index_id = nicbm.index_id
	AND
		nicb.index_column_id = nicbm.index_column_id
	INNER JOIN
		sys.indexes i
	ON
		nicb.object_id = i.object_id
	AND
		nicb.index_id = i.index_id
)
SELECT @SQL = @SQL + ISNULL('
	CREATE ' +
	CASE WHEN ic.is_unique = 1 THEN ' UNIQUE ' ELSE '' END + ic.IndexType +
	' INDEX ' + ic.IndexName + ' ' +
	' ON [' + @TargetSchema + '].[' + @TableName + '] (' + ic.NonIncludedColumnList + ')' +
	CASE WHEN ISNULL(ic.IncludedColumnList, '') <> '' THEN ' INCLUDE (' + ic.IncludedColumnList + ')' ELSE '' END, '')
FROM 
	CTE_IndexColumns ic
WHERE
	object_name(ic.object_id) = @TableName
AND
	object_schema_name(ic.object_id) = @TableSchema


;WITH CTE_IndexColumnBuilder AS
(	SELECT
		ic.object_id,
		ic.index_id,
		CONVERT(VARCHAR(MAX), c.name) AS ColumnList,
		ic.index_column_id
	FROM
		sys.indexes i
	INNER JOIN
		sys.index_columns ic
	ON
		ic.object_id = i.object_id
	AND
		ic.index_id = i.index_id
	INNER JOIN
		sys.columns c
	ON
		ic.object_id = c.object_id
	AND
		ic.column_id = c.column_id
	WHERE
		ic.index_column_id = 1
	AND
		i.is_primary_key = 1
	UNION ALL
	SELECT
		nic.object_id,
		nic.index_id,
		CONVERT(VARCHAR(MAX), ColumnList + CASE WHEN is_included_column = 0 THEN ',' + c.name ELSE '' END) AS ColumnList,
		ic.index_column_id
	FROM
		CTE_IndexColumnBuilder nic
	INNER JOIN
		sys.index_columns ic
	ON
		nic.object_id = ic.object_id
	AND
		nic.index_id = ic.index_id
	INNER JOIN
		sys.columns c
	ON
		ic.object_id = c.object_id
	AND
		ic.column_id = c.column_id
	WHERE
		ic.index_column_id = nic.index_column_id + 1
), CTE_IndexColumnBuilderMax AS
(
	SELECT
		object_id,
		index_id,
		MAX(index_column_id) AS index_column_id
	FROM
		CTE_IndexColumnBuilder
	GROUP BY
		object_id,
		index_id

), CTE_IndexColumns AS
(
	SELECT
		nicb.object_id,
		nicb.index_id,
		i.name COLLATE DATABASE_DEFAULT AS IndexName,
		nicb.ColumnList,
		i.type_desc COLLATE DATABASE_DEFAULT AS IndexType
	FROM
		CTE_IndexColumnBuilder nicb
	INNER JOIN
		CTE_IndexColumnBuilderMax nicbm
	ON
		nicb.object_id = nicbm.object_id
	AND
		nicb.index_id = nicbm.index_id
	AND
		nicb.index_column_id = nicbm.index_column_id
	INNER JOIN
		sys.indexes i
	ON
		nicb.object_id = i.object_id
	AND
		nicb.index_id = i.index_id
)
SELECT @SQL = @SQL + ISNULL('ALTER TABLE [' + @TargetSchema + '].[' + @TableName + '] ADD CONSTRAINT ' + ic.IndexName + 
	' PRIMARY KEY ' + ic.IndexType +
	' (' + ic.ColumnList + ')', '')
FROM 
	CTE_IndexColumns ic
WHERE
	object_name(ic.object_id) = @TableName
AND
	object_schema_name(ic.object_id) = @TableSchema

SET @SQL = @SQL + '
'

SELECT @SQL
