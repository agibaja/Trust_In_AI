WITH usage AS (
    SELECT a.respondent_id, c.code::INTEGER AS usage_score, c.label AS usage_label
    FROM survey.answers a
    JOIN raw.answer_codes c
      ON c.code_column = 'ai_share_of_workday_code' AND c.label = a.text_value
    WHERE a.question_code = 'ai_share_of_workday'
)
SELECT u.usage_score, u.usage_label, COUNT(*) AS respondents,
       ROUND(AVG(t.trust_score), 2) AS avg_trust
FROM usage u
JOIN survey.v_ai_trust t ON t.respondent_id = u.respondent_id
JOIN survey.eligible_respondents(%(countries)s, %(roles)s, %(age_groups)s,
                                 %(min_years)s, %(max_years)s) e
  ON e.respondent_id = u.respondent_id
GROUP BY u.usage_score, u.usage_label
ORDER BY u.usage_score;
