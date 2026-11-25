-- Visualization support for Q10: discrete histogram, SQL-only aggregation.
-- Population: respondents above the mean number of tasks among respondents
-- who answered tasks_delegated_to_agents; identical to Q10.
WITH per_respondent AS (
  SELECT respondent_id, COUNT(*) AS task_kinds
  FROM survey.answers
  WHERE question_code = 'tasks_delegated_to_agents'
  GROUP BY respondent_id
), mean_count AS (
  SELECT AVG(task_kinds) AS average_tasks FROM per_respondent
)
SELECT p.task_kinds, COUNT(*) AS respondents
FROM per_respondent p
CROSS JOIN mean_count m
WHERE p.task_kinds > m.average_tasks
GROUP BY p.task_kinds
ORDER BY p.task_kinds;
