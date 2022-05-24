SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/****************************************************************************************************************************************************
	Title : dbo_c.AllPermissions

	Description:
		Provides data all principals

	Change History:
		Date		Author          Version	Description
		----------	--------------- -------	------------------------------------
		2021-09-15	Chris Faulkner	1.00	Created

****************************************************************************************************************************************************/
CREATE VIEW [dbo_c].[AllPermissions] AS
WITH CTE_AllPermissions AS
(
SELECT
	u.name AS ObjectName,
	u.type_desc AS ObjectType,
	dp.state_desc AS PermissionState,
	dp.permission_name AS PermissionName,
	dp.class_desc AS TargetObjectType,
	CASE dp.class_desc
		WHEN 'DATABASE' THEN DB_NAME()
		WHEN 'SCHEMA' THEN sc.name
		WHEN 'OBJECT_OR_COLUMN' THEN obj_sch.name + '.' + obj.name + ISNULL('.' + col.name, '')
--		ELSE CONVERT(varchar(10), dp.major_id)
	END AS TargetObjectName
FROM
	sys.database_principals u
INNER JOIN
	sys.database_permissions dp
ON
	dp.grantee_principal_id = u.principal_id
LEFT JOIN
	sys.schemas sc
ON
	sc.schema_id = dp.major_id
AND
	dp.class_desc = 'SCHEMA'
LEFT JOIN
	sys.all_objects obj
ON
	obj.object_id = dp.major_id
AND
	dp.class_desc = 'OBJECT_OR_COLUMN'
LEFT JOIN
	sys.schemas obj_sch
ON
	obj_sch.schema_id = obj.schema_id
LEFT JOIN
	sys.all_columns col
ON
	col.object_id = dp.major_id
AND
	col.column_id = dp.minor_id
UNION
SELECT
	u.name AS ObjectName,
	u.type_desc AS ObjectType,
	'GRANT' AS PermissionState,
	'MEMBER' AS PermissionName,
	r.type_desc AS TargetObjectType,
	r.name AS TargetObjectName
FROM
	sys.database_principals u
INNER JOIN
	sys.database_role_members rm
ON
	u.principal_id=rm.member_principal_id
INNER JOIN
	sys.database_principals r
ON
	r.principal_id = rm.role_principal_id
)
SELECT TOP 1000000 *
FROM
	CTE_AllPermissions
ORDER BY
	ObjectName, PermissionState, PermissionName, TargetObjectName 

GO
/*
SELECT DP1.name AS DatabaseRoleName,   
   isnull (DP2.name, 'No members') AS DatabaseUserName   
 FROM sys.database_role_members AS DRM  
 RIGHT OUTER JOIN sys.database_principals AS DP1  
   ON DRM.role_principal_id = DP1.principal_id  
 LEFT OUTER JOIN sys.database_principals AS DP2  
   ON DRM.member_principal_id = DP2.principal_id  
WHERE DP1.type = 'R'
ORDER BY DP1.name;  
*/

/*
SELECT
	sc.name AS SchemaName,
	sco.name AS SchemaOwner
FROM
	sys.schemas sc
INNER JOIN
	sys.database_principals sco
ON
	sco.principal_id = sc.principal_id
ORDER BY 1,2
*/

