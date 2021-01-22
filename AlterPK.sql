SET NOCOUNT ON

DECLARE @SchemaName varchar(255)
DECLARE @TableName varchar(255) = NULL
DECLARE @FullTableName varchar(255) = NULL
DECLARE @PKName varchar(255), @PKColumns varchar(255)
DECLARE @TSQL varchar(MAX)
DECLARE @CreateFKScript varchar(MAX)
DECLARE @DropFKScript varchar(MAX)

DECLARE csr_MartName CURSOR LOCAL FORWARD_ONLY READ_ONLY FOR
SELECT '' + CODE + '_store'
FROM dbo.MART

OPEN csr_MartName

FETCH NEXT
FROM csr_MartName
INTO @SchemaName

WHILE @@FETCH_STATUS = 0
BEGIN

	DECLARE csr_TableName CURSOR LOCAL FORWARD_ONLY READ_ONLY FOR
	SELECT DISTINCT t.TABLE_NAME
	FROM INFORMATION_SCHEMA.TABLES t
	WHERE t.TABLE_SCHEMA = @SchemaName
	AND t.TABLE_TYPE = 'BASE TABLE'

	OPEN csr_TableName

	FETCH NEXT
	FROM csr_TableName
	INTO @TableName

	WHILE @@FETCH_STATUS = 0
	BEGIN
		SET @FullTableName = @SchemaName + '.' + @TableName
		RAISERROR(@FullTableName, 0, 0) WITH NOWAIT
		SET @TSQL = NULL

		SET @DropFKScript = NULL
		SET @CreateFKScript = NULL

		SELECT
			@DropFKScript = ISNULL(@DropFKScript, '') +
				'ALTER TABLE [' + OBJECT_SCHEMA_NAME(fk.parent_object_id) + '].[' + OBJECT_NAME(fk.parent_object_id) + '] ' +
				'DROP CONSTRAINT ' + fk.name + '; ',
			@CreateFKScript = ISNULL(@CreateFKScript, '') +
				'ALTER TABLE [' + OBJECT_SCHEMA_NAME(fk.parent_object_id) + '].[' + OBJECT_NAME(fk.parent_object_id) + '] ' +
				'ADD CONSTRAINT ' + fk.name + ' FOREIGN KEY ' +
				'([' + cp.name + ']) ' +
				'REFERENCES [' + OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '].[' + OBJECT_NAME(fk.referenced_object_id) + '] ' +
				'([' + cr.name + ']); '
		FROM
			INFORMATION_SCHEMA.TABLES t
		INNER JOIN
			sys.foreign_keys fk
		ON
			OBJECT_NAME(fk.referenced_object_id) = t.TABLE_NAME
		AND
			OBJECT_SCHEMA_NAME(fk.referenced_object_id) = t.TABLE_SCHEMA
		INNER JOIN
			sys.foreign_key_columns fkc
		ON
			fk.object_id = fkc.constraint_object_id
		INNER JOIN
			sys.columns cp
		ON
			cp.object_id = fkc.parent_object_id
		AND
			cp.column_id = fkc.parent_column_id
		INNER JOIN
			sys.columns cr
		ON
			cr.object_id = fkc.referenced_object_id
		AND
			cr.column_id = fkc.referenced_column_id
		WHERE
			t.TABLE_SCHEMA = @SchemaName
		AND
			t.TABLE_TYPE = 'BASE TABLE'


		SELECT @PKName = CONSTRAINT_NAME
		FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
		WHERE TABLE_SCHEMA = @SchemaName
		AND TABLE_NAME = @TableName
		AND CONSTRAINT_TYPE = 'PRIMARY KEY'

		-- If the PK Is Clustered
		IF EXISTS (	SELECT *
					FROM	sys.indexes
					WHERE	OBJECT_SCHEMA_NAME(OBJECT_ID) = @SchemaName
					AND		OBJECT_NAME(object_id) = @TableName
					AND		Name = @PKName
					AND		is_primary_key = 1
					AND		type_desc = 'CLUSTERED'
					)
		BEGIN

			SET @TSQL = ''
			IF NOT EXISTS (	SELECT *
							FROM INFORMATION_SCHEMA.COLUMNS
							WHERE TABLE_SCHEMA = @SchemaName
							AND TABLE_NAME = @TableName
							AND COLUMN_NAME = 'Sys_PK'
			)
			BEGIN
				SET @TSQL = 
				'RAISERROR (''' + CONVERT(VARCHAR(10), getdate(), 108) + ' : Adding ' + @FullTableName + '.Sys_PK'', 0, 0) WITH NOWAIT
				ALTER TABLE [' + @SchemaName + '].[' + @TableName +
				'] ADD Sys_PK INT IDENTITY(-2147483648, 1) NOT NULL;
				'
			END

			SET @PKColumns = NULL

			--SELECT @PKColumns = ISNULL(@PKColumns + ',', '') + COLUMN_NAME
			--FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE
			--			WHERE TABLE_SCHEMA = @SchemaName
			--			AND TABLE_NAME = @TableName
			--			AND COLUMN_NAME = 'Sys_PK'

			SELECT @PKColumns = ISNULL(@PKColumns + ',', '') + COLUMN_NAME
			FROM INFORMATION_SCHEMA.CONSTRAINT_COLUMN_USAGE
						WHERE TABLE_SCHEMA = @SchemaName
						AND TABLE_NAME = @TableName
						AND CONSTRAINT_NAME = @PKName

			-- Convert PK from Clustered to Non-Clustered
			IF @PKColumns IS NOT NULL
			BEGIN
				IF @DropFKScript IS NOT NULL
				BEGIN
					SET @TSQL = @TSQL +
						'RAISERROR (''' + CONVERT(VARCHAR(10), getdate(), 108) + ' : Dropping FKs Which Reference ' + @FullTableName + ''', 0, 0) WITH NOWAIT '
							+ @DropFKScript
				END

				SET @TSQL = @TSQL +
				'RAISERROR (''' + CONVERT(VARCHAR(10), getdate(), 108) + ' : Rebuilding ' + @FullTableName + '.' + @PKName + ' as Non-Clustered PK'', 0, 0) WITH NOWAIT
				ALTER TABLE [' + @SchemaName + '].[' + @TableName + '] DROP CONSTRAINT ' + @PKName + ';
				ALTER TABLE [' + @SchemaName + '].[' + @TableName + '] ADD CONSTRAINT ' + @PKName +
				' PRIMARY KEY NONCLUSTERED (' + @PKColumns + ');
				'
				IF @CreateFKScript IS NOT NULL
				BEGIN
					SET @TSQL = @TSQL +
						'RAISERROR (''' + CONVERT(VARCHAR(10), getdate(), 108) + ' : Creating FKs Which Reference ' + @FullTableName + ''', 0, 0) WITH NOWAIT; '
							+ @CreateFKScript
				END
	
				SET @TSQL = @TSQL + 
				'RAISERROR (''' + CONVERT(VARCHAR(10), getdate(), 108) + ' : Creating Clustered Index UQ_' + @TableName + '_Sys_PK'', 0, 0) WITH NOWAIT; 
				CREATE UNIQUE CLUSTERED INDEX UQ_' + @TableName + '_Sys_PK ' +
				' ON [' + @SchemaName + '].[' + @TableName + '] (Sys_PK); '
			END
		END

		IF @TSQL IS NOT NULL
		BEGIN
			SELECT @TSQL
			EXEC (@TSQL)
		END
		FETCH NEXT
		FROM csr_TableName
		INTO @TableName

	END

	CLOSE csr_TableName
	DEALLOCATE csr_TableName

	FETCH NEXT
	FROM csr_MartName
	INTO @SchemaName
END

CLOSE csr_MartName
DEALLOCATE csr_MartName
