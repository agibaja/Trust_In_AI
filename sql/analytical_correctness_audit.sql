-- Project B: independent, read-only analytical correctness checks.
-- Run: python run_sql_file.py sql/analytical_correctness_audit.sql analytical_audit
-- Review any REVIEW/FAIL and inspect the numeric diagnostics.

-- 01. Trust view: row uniqueness, score range, and source-vs-derived coverage.
WITH baseline AS (
 SELECT COUNT(DISTINCT a.respondent_id) AS source_on_scale
 FROM survey.answers a JOIN raw.answer_codes c
   ON c.code_column='ai_trust_code' AND c.label=a.text_value
 WHERE a.question_code='ai_trust' AND c.code ~ '^[0-4]$'
), checks AS (
 SELECT COUNT(*) AS view_rows, COUNT(DISTINCT respondent_id) AS unique_respondents,
        COUNT(*) FILTER (WHERE trust_score NOT BETWEEN 0 AND 4 OR trust_score IS NULL) AS invalid_scores
 FROM survey.v_ai_trust
)
SELECT '01 trust mapping and uniqueness' AS test, baseline.source_on_scale,
 checks.view_rows, checks.unique_respondents, checks.invalid_scores,
 CASE WHEN baseline.source_on_scale=checks.view_rows
        AND checks.view_rows=checks.unique_respondents AND checks.invalid_scores=0
      THEN 'PASS' ELSE 'REVIEW' END AS status
FROM baseline CROSS JOIN checks;

-- 02. Q03 trust distribution sums: all trust levels vs eligible view.
WITH distribution AS (
 SELECT trust_score, COUNT(*) AS n FROM survey.v_ai_trust GROUP BY trust_score
), totals AS (
 SELECT COALESCE(SUM(n),0) AS distribution_total FROM distribution
)
SELECT '02 trust distribution totals' AS test, totals.distribution_total,
 (SELECT COUNT(*) FROM survey.v_ai_trust) AS expected_total,
 CASE WHEN totals.distribution_total=(SELECT COUNT(*) FROM survey.v_ai_trust)
 THEN 'PASS' ELSE 'FAIL' END AS status FROM totals;

-- 03. Q05: check that role-weighted average equals raw-row average.
WITH role_data AS (
 SELECT w.role, COUNT(*)::NUMERIC AS n, SUM(t.trust_score)::NUMERIC AS total
 FROM survey.v_ai_trust t JOIN survey.work_info w USING (respondent_id)
 WHERE w.role IS NOT NULL GROUP BY w.role
), calc AS (
 SELECT SUM(total)/NULLIF(SUM(n),0) AS weighted_avg,
 AVG(total/NULLIF(n,0)) AS unweighted_role_avg FROM role_data
)
SELECT '03 weighted overall trust by role' AS test,
 ROUND(weighted_avg,4) AS weighted_overall,
 ROUND((SELECT AVG(t.trust_score) FROM survey.v_ai_trust t
 JOIN survey.work_info w USING (respondent_id) WHERE w.role IS NOT NULL),4) AS direct_overall,
 ROUND(unweighted_role_avg,4) AS incorrect_unweighted_role_avg,
 CASE WHEN ABS(weighted_avg-(SELECT AVG(t.trust_score) FROM survey.v_ai_trust t
 JOIN survey.work_info w USING (respondent_id) WHERE w.role IS NOT NULL)) < 0.000001
 THEN 'PASS' ELSE 'FAIL' END AS status FROM calc;

-- 04. Q07: low/medium/high partition accounts for every respondent in the trust view.
WITH segmented AS (
 SELECT CASE WHEN trust_score<=1 THEN 'Low' WHEN trust_score=2 THEN 'Medium'
 ELSE 'High' END AS segment FROM survey.v_ai_trust
)
SELECT '04 trust segment partition' AS test,
 COUNT(*) FILTER (WHERE segment='Low') AS low_count,
 COUNT(*) FILTER (WHERE segment='Medium') AS medium_count,
 COUNT(*) FILTER (WHERE segment='High') AS high_count,
 COUNT(*) AS total,
 CASE WHEN COUNT(*)=(SELECT COUNT(*) FROM survey.v_ai_trust) THEN 'PASS' ELSE 'FAIL' END AS status
FROM segmented;

-- 05. Q08: AI-assisted language users MUST be a subset of language users.
WITH used AS (
 SELECT DISTINCT a.respondent_id, ao.option_text AS language
 FROM survey.answers a JOIN survey.answer_options ao ON ao.option_id=a.option_id
 WHERE a.question_code='languages_used'
), with_ai AS (
 SELECT DISTINCT a.respondent_id, ao.option_text AS language
 FROM survey.answers a JOIN survey.answer_options ao ON ao.option_id=a.option_id
 WHERE a.question_code='languages_with_ai'
), counts AS (
 SELECT language, COUNT(*) AS users,
 COUNT(*) FILTER (WHERE EXISTS
  (SELECT 1 FROM with_ai w WHERE w.respondent_id=u.respondent_id AND w.language=u.language)) AS ai_users
 FROM used u GROUP BY language
)
SELECT '05 language AI percentage bounds' AS test, COUNT(*) AS languages,
 COUNT(*) FILTER (WHERE ai_users>users OR users=0) AS invalid_groups,
 MIN(ROUND(100.0*ai_users/NULLIF(users,0),2)) AS min_pct,
 MAX(ROUND(100.0*ai_users/NULLIF(users,0),2)) AS max_pct,
 CASE WHEN COUNT(*) FILTER (WHERE ai_users>users OR users=0)=0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts;

-- 06. Q08: number of AI-language combinations NOT in languages_used.
-- Such combinations are not automatically wrong; they limit interpretation of the denominator.
WITH used AS (
 SELECT DISTINCT a.respondent_id, ao.option_text AS language
 FROM survey.answers a JOIN survey.answer_options ao ON ao.option_id=a.option_id
 WHERE a.question_code='languages_used'
), with_ai AS (
 SELECT DISTINCT a.respondent_id, ao.option_text AS language
 FROM survey.answers a JOIN survey.answer_options ao ON ao.option_id=a.option_id
 WHERE a.question_code='languages_with_ai'
)
SELECT '06 AI-language selections not in used-language selections' AS test,
 COUNT(*) AS selections_not_in_used,
 CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'REVIEW' END AS status
FROM with_ai w LEFT JOIN used u ON u.respondent_id=w.respondent_id AND u.language=w.language
WHERE u.respondent_id IS NULL;

-- 07. Q09/Q12/Q13: duplicate respondent-question-option selections.
SELECT '07 repeated selected options' AS test, COUNT(*) AS violating_groups,
 CASE WHEN COUNT(*)=0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (SELECT respondent_id, question_code, option_id FROM survey.answers
 WHERE option_id IS NOT NULL GROUP BY 1,2,3 HAVING COUNT(*)>1) dup;

-- 08. Q12: wanted databases intersect USED databases; numerator <= denominator.
WITH used AS (
 SELECT DISTINCT a.respondent_id, ao.technology_id
 FROM survey.answers a JOIN survey.answer_options ao ON ao.option_id=a.option_id
 WHERE a.question_code='databases_used' AND ao.technology_id IS NOT NULL
), wanted AS (
 SELECT DISTINCT a.respondent_id, ao.technology_id
 FROM survey.answers a JOIN survey.answer_options ao ON ao.option_id=a.option_id
 WHERE a.question_code='databases_wanted' AND ao.technology_id IS NOT NULL
), counts AS (
 SELECT u.technology_id, COUNT(*) AS users, COUNT(w.respondent_id) AS want_to_keep
 FROM used u LEFT JOIN wanted w ON w.respondent_id=u.respondent_id
   AND w.technology_id=u.technology_id GROUP BY u.technology_id
)
SELECT '08 database retention subset' AS test, COUNT(*) AS databases,
 COUNT(*) FILTER (WHERE want_to_keep>users) AS invalid_groups,
 MAX(ROUND(100.0*want_to_keep/NULLIF(users,0),2)) AS max_retention_pct,
 CASE WHEN COUNT(*) FILTER (WHERE want_to_keep>users)=0 THEN 'PASS' ELSE 'FAIL' END AS status
FROM counts;

-- 09. Q11: verify usage codes have clean mapping and no duplicate joined rows.
WITH usage AS (
 SELECT a.respondent_id, a.text_value, c.code
 FROM survey.answers a LEFT JOIN raw.answer_codes c
  ON c.code_column='ai_share_of_workday_code' AND c.label=a.text_value
 WHERE a.question_code='ai_share_of_workday'
)
SELECT '09 AI-usage code mapping' AS test, COUNT(*) AS usage_rows,
 COUNT(*) FILTER (WHERE code IS NULL) AS unmatched_codes,
 COUNT(*) FILTER (WHERE code IS NOT NULL AND code !~ '^[0-9]+$') AS nonnumeric_codes,
 COUNT(DISTINCT respondent_id) AS distinct_respondents,
 CASE WHEN COUNT(*) FILTER (WHERE code IS NULL OR (code IS NOT NULL AND code !~ '^[0-9]+$'))=0
 AND COUNT(*)=COUNT(DISTINCT respondent_id) THEN 'PASS' ELSE 'REVIEW' END AS status
FROM usage;

-- 10. Q10/Q13/Q14: availability of exact question codes among retained survey answers.
WITH expected(q) AS (
 VALUES ('languages_used'),('languages_with_ai'),('databases_used'),
 ('databases_wanted'),('tasks_delegated_to_agents'),('ai_coding_agents_used'),
 ('ai_share_of_workday'),('ai_trust')
)
SELECT '10 required question coverage' AS test, e.q AS question_code,
 COUNT(a.answer_id) AS answer_rows, COUNT(DISTINCT a.respondent_id) AS respondents,
 CASE WHEN COUNT(a.answer_id)>0 THEN 'PASS' ELSE 'REVIEW' END AS status
FROM expected e LEFT JOIN survey.answers a ON a.question_code=e.q
GROUP BY e.q ORDER BY e.q;

-- 11. Q14: check country partition rankings (first rank should be 1 everywhere).
WITH counts AS (
 SELECT r.country, ao.option_text AS language, COUNT(DISTINCT a.respondent_id) AS users
 FROM survey.answers a JOIN survey.respondents r USING (respondent_id)
 JOIN survey.answer_options ao ON ao.option_id=a.option_id
 WHERE a.question_code='languages_used' AND r.country IS NOT NULL
 GROUP BY r.country, ao.option_text
), ranks AS (
 SELECT country, language, RANK() OVER (PARTITION BY country ORDER BY users DESC) AS rank_in_country
 FROM counts
)
SELECT '11 country ranking starts at one' AS test, COUNT(DISTINCT country) AS countries,
 COUNT(DISTINCT country) FILTER (WHERE rank_in_country=1) AS countries_with_rank_one,
 CASE WHEN COUNT(DISTINCT country)=COUNT(DISTINCT country) FILTER (WHERE rank_in_country=1)
 THEN 'PASS' ELSE 'FAIL' END AS status FROM ranks;

-- 12. Demographic filter behavior: selecting Spain cannot increase eligible total.
WITH totals AS (
 SELECT COUNT(*) AS n_all FROM survey.eligible_respondents(NULL,NULL,NULL,NULL,NULL)
), filtered AS (
 SELECT COUNT(*) AS n_spain FROM survey.eligible_respondents(ARRAY['Spain']::TEXT[],NULL,NULL,NULL,NULL)
)
SELECT '12 demographic filter subset' AS test, n_all, n_spain,
 CASE WHEN n_spain<=n_all AND n_all=(SELECT COUNT(*) FROM survey.respondents)
 THEN 'PASS' ELSE 'FAIL' END AS status FROM totals CROSS JOIN filtered;
