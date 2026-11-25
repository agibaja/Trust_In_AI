SELECT t.trust_score, t.trust_label, COUNT(*) AS respondents
FROM survey.v_ai_trust t
JOIN survey.eligible_respondents(%(countries)s, %(roles)s, %(age_groups)s,
                                 %(min_years)s, %(max_years)s) e
  ON e.respondent_id = t.respondent_id
GROUP BY t.trust_score, t.trust_label
ORDER BY t.trust_score;
