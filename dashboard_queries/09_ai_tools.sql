SELECT t.technology_name,
       COUNT(DISTINCT a.respondent_id) AS users,
       ROUND(AVG(tr.trust_score), 2)   AS avg_trust
FROM survey.answers a
JOIN survey.answer_options ao ON ao.option_id = a.option_id
JOIN survey.technologies t    ON t.technology_id = ao.technology_id
JOIN survey.v_ai_trust tr     ON tr.respondent_id = a.respondent_id
JOIN survey.eligible_respondents(%(countries)s, %(roles)s, %(age_groups)s,
                                 %(min_years)s, %(max_years)s) e
  ON e.respondent_id = a.respondent_id
WHERE a.question_code = 'ai_coding_agents_used'
GROUP BY t.technology_name
HAVING COUNT(DISTINCT a.respondent_id) > %(min_users)s
ORDER BY avg_trust DESC;
