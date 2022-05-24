DECLARE @testtemp TABLE (ISO3 char(3), WeekNo int, Val1 int, Val2 int)

INSERT INTO @testtemp (ISO3, WeekNo, Val1, Val2)
VALUES
('CHN', 1, 1000, 1000),
('CHN', 2, NULL, 2000),
('CHN', 3, 2000, NULL),
('CHN', 4, NULL, NULL),  
('HKG', 1, 100,  150),
('HKG', 2, 200,  NULL),
('HKG', 3, NULL, 250),
('HKG', 4, 400,  350),
('MAC', 1, 10,    15),
('MAC', 2, 20,    25),
('MAC', 3, 30,    35),
('MAC', 4, 40,    45) 


SELECT * FROM @testtemp
ORDER BY ISO3, WeekNo

;WITH CTE_LastNotNull AS
(
SELECT
	tt.ISO3,
	tt.WeekNo,
	MAX(nn1.WeekNo) AS Val1NotNullWeekNo,
	MAX(nn2.WeekNo) AS Val2NotNullWeekNo
FROM
	@testtemp tt
LEFT JOIN
	@testtemp nn1
ON
	tt.ISO3 = nn1.ISO3
AND
	nn1.WeekNo <= tt.WeekNo
AND
	nn1.Val1 IS NOT NULL
LEFT JOIN
	@testtemp nn2
ON
	tt.ISO3 = nn2.ISO3
AND
	nn2.WeekNo <= tt.WeekNo
AND
	nn2.Val2 IS NOT NULL
GROUP BY tt.ISO3, tt.WeekNo
)
SELECT
	tt.ISO3,
	tt.WeekNo,
	v1.Val1,
	v2.Val2
--	SUM(tt.Val) AS Total
FROM
	@testtemp tt
INNER JOIN
	CTE_LastNotNull lnn
ON
	tt.ISO3 = lnn.ISO3
AND
	tt.WeekNo = lnn.WeekNo
INNER JOIN
	@testtemp v1
ON
	v1.ISO3 = lnn.ISO3
AND
	v1.WeekNo  = lnn.Val1NotNullWeekNo
INNER JOIN
	@testtemp v2
ON
	v2.ISO3 = lnn.ISO3
AND
	v2.WeekNo  = lnn.Val2NotNullWeekNo
--GROUP BY
--	tt.ISO3,
--	tt.WeekNo
ORDER BY ISO3, WeekNo
