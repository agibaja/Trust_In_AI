-- 7b: trust segments by coding experience, one row per bucket and segment.
WITH segments AS (
    SELECT r.respondent_id,
           CASE WHEN r.years_coding < 5 THEN '0-4 years'
                WHEN r.years_coding < 10 THEN '5-9 years'
                WHEN r.years_coding < 20 THEN '10-19 years'
                WHEN r.years_coding < 30 THEN '20-29 years'
                ELSE '30+ years' END AS grouping,
           CASE WHEN t.trust_score <= 1 THEN 'Low'
                WHEN t.trust_score = 2 THEN 'Medium'
                ELSE 'High' END AS segment
    FROM survey.v_ai_trust t
    JOIN survey.respondents r ON r.respondent_id = t.respondent_id
    JOIN survey.eligible_respondents(%(countries)s, %(roles)s, %(age_groups)s,
                                     %(min_years)s, %(max_years)s) e
      ON e.respondent_id = t.respondent_id
    WHERE r.years_coding IS NOT NULL
)
SELECT grouping, segment, COUNT(*) AS respondents
FROM segments
GROUP BY grouping, segment
ORDER BY CASE grouping WHEN '0-4 years' THEN 1 WHEN '5-9 years' THEN 2
                       WHEN '10-19 years' THEN 3 WHEN '20-29 years' THEN 4 ELSE 5 END, segment;
