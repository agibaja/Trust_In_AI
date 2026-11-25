WITH bucketed AS (
    SELECT CASE WHEN r.years_coding < 5  THEN 1 WHEN r.years_coding < 10 THEN 2
                WHEN r.years_coding < 20 THEN 3 WHEN r.years_coding < 30 THEN 4 ELSE 5 END AS bucket_order,
           CASE WHEN r.years_coding < 5  THEN '0-4 years'   WHEN r.years_coding < 10 THEN '5-9 years'
                WHEN r.years_coding < 20 THEN '10-19 years' WHEN r.years_coding < 30 THEN '20-29 years'
                ELSE '30+ years' END AS bucket,
           t.trust_score
    FROM survey.v_ai_trust t
    JOIN survey.respondents r ON r.respondent_id = t.respondent_id
    JOIN survey.eligible_respondents(%(countries)s, %(roles)s, %(age_groups)s,
                                     %(min_years)s, %(max_years)s) e
      ON e.respondent_id = t.respondent_id
    WHERE r.years_coding IS NOT NULL
), agg AS (
    SELECT bucket_order, bucket, COUNT(*) AS respondents, AVG(trust_score) AS avg_trust
    FROM bucketed
    GROUP BY bucket_order, bucket
)
SELECT bucket, respondents, ROUND(avg_trust, 2) AS avg_trust,
       ROUND(avg_trust - LAG(avg_trust) OVER (ORDER BY bucket_order), 2) AS change_from_previous
FROM agg
ORDER BY bucket_order;
