-- Visualization support for Q13: discrete histogram, SQL-only aggregation.
-- Mean is computed among those who answered languages_used, as in Q13.
WITH per_respondent AS (
  SELECT respondent_id, COUNT(*) AS languages
  FROM survey.answers
  WHERE question_code = 'languages_used'
  GROUP BY respondent_id
), language_average AS (
  SELECT AVG(languages) AS avg_languages FROM per_respondent
)
SELECT p.languages, COUNT(*) AS respondents
FROM per_respondent p
CROSS JOIN language_average a
WHERE p.languages > a.avg_languages
GROUP BY p.languages
ORDER BY p.languages;
