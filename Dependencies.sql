/****************************************************************************************************************************************************
	Title : Dependecies

	Description:
		Which view is called from another view 

	Change History:
		Date		Author          Version	Description
		----------	--------------- -------	------------------------------------
		2019-??-??	Chris Faulkner	1.00	Created

****************************************************************************************************************************************************/
WITH CTE_RefChain AS
(
	SELECT
		object_name(referenced_id) AS ViewName,
		object_name(referencing_id) AS ReferencedFrom
	FROM
		sys.sql_expression_dependencies
	UNION ALL
	SELECT
		object_name(referenced_id) AS ViewName,
		object_name(referencing_id) AS ReferencedFrom
	FROM
		sys.sql_expression_dependencies
	INNER JOIN
		CTE_RefChain
	ON
		object_name(referenced_id) = ReferencedFrom
)
SELECT DISTINCT * FROM CTE_RefChain
ORDER BY 1
