-- 7a. filter by role
WITH segments AS (
    SELECT t.respondent_id,
           CASE WHEN t.trust_score <= 1 THEN 'Low'
                WHEN t.trust_score = 2  THEN 'Medium'
                ELSE 'High' END AS segment
    FROM survey.v_ai_trust t
    JOIN survey.eligible_respondents(%(countries)s, %(roles)s, %(age_groups)s,
                                     %(min_years)s, %(max_years)s) e
      ON e.respondent_id = t.respondent_id
)
SELECT w.role AS grouping, s.segment, COUNT(*) AS respondents
FROM segments s
JOIN survey.work_info w ON w.respondent_id = s.respondent_id
WHERE w.role IS NOT NULL
GROUP BY w.role, s.segment
ORDER BY w.role, s.segment;
