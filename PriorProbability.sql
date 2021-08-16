DECLARE @Population float = 1000000
DECLARE @PriorProbability float = 0.01 --(2950 / @Pop)
DECLARE @FailureProbability float = 0.1
DECLARE @FailureCount float = ((1 - @PriorProbability) * @FailureProbability)


SELECT

@PriorProbability * @Population AS TruePositive,
@FailureCount * @Population AS FalsePositive,
(@FailureCount + @PriorProbability) * @Population AS TotalPositive,
@FailureCount / (@FailureCount + @PriorProbability) AS PercentWrong

