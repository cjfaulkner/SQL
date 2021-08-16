DECLARE @SQL varchar(MAX)
DECLARE @Results TABLE (TableName varchar(255), RecordCount int)

DECLARE csr_SQL CURSOR LOCAL FORWARD_ONLY READ_ONLY FOR
SELECT 'SELECT ''' + TABLE_SCHEMA + '.' + TABLE_NAME + ''' AS TableName, COUNT(*) AS RecordCount FROM ' + TABLE_SCHEMA + '.' + TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME

OPEN csr_SQL

FETCH NEXT
FROM csr_SQL
INTO @SQL

WHILE @@FETCH_STATUS = 0
BEGIN

	INSERT INTO @Results (TableName, RecordCount)
	EXEC(@SQL)

	FETCH NEXT
	FROM csr_SQL
	INTO @SQL
END

CLOSE csr_SQL
DEALLOCATE csr_SQL

SELECT * FROM @Results

