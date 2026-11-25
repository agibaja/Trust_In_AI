WITH used AS (
    SELECT a.respondent_id, ao.technology_id
    FROM survey.answers a
    JOIN survey.answer_options ao ON ao.option_id = a.option_id
    JOIN survey.eligible_respondents(%(countries)s, %(roles)s, %(age_groups)s,
                                     %(min_years)s, %(max_years)s) e
      ON e.respondent_id = a.respondent_id
    WHERE a.question_code = 'databases_used'
), wanted AS (
    SELECT a.respondent_id, ao.technology_id
    FROM survey.answers a
    JOIN survey.answer_options ao ON ao.option_id = a.option_id
    WHERE a.question_code = 'databases_wanted'
)
SELECT t.technology_name,
       COUNT(*)              AS users,
       COUNT(w.respondent_id) AS want_to_keep,
       ROUND(100.0 * COUNT(w.respondent_id) / COUNT(*), 1) AS pct_keep
FROM used u
JOIN survey.technologies t ON t.technology_id = u.technology_id
LEFT JOIN wanted w ON w.respondent_id = u.respondent_id
                  AND w.technology_id = u.technology_id
GROUP BY t.technology_name
HAVING COUNT(*) >= %(min_users)s
ORDER BY pct_keep DESC;
