SELECT w.role, COUNT(*) AS respondents, ROUND(AVG(t.trust_score), 2) AS avg_trust
FROM survey.v_ai_trust t
JOIN survey.work_info w ON w.respondent_id = t.respondent_id
JOIN survey.eligible_respondents(%(countries)s, %(roles)s, %(age_groups)s,
                                 %(min_years)s, %(max_years)s) e
  ON e.respondent_id = t.respondent_id
WHERE w.role IS NOT NULL
GROUP BY w.role
ORDER BY avg_trust DESC;
