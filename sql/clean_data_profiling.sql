-- Missingness denominator = all columns in raw.respondents EXCEPT respondent_id.
WITH missing AS (
 SELECT r.respondent_id::INTEGER AS respondent_id,
        count(*) AS fields_checked,
        count(*) FILTER (WHERE v.value IS NULL OR btrim(v.value)='') AS missing_fields
 FROM raw.respondents r
 CROSS JOIN LATERAL jsonb_each_text(to_jsonb(r)-'respondent_id') v(column_name,value)
 GROUP BY r.respondent_id
), classified AS (
 SELECT respondent_id,
        100.0*missing_fields/NULLIF(fields_checked,0) AS missing_pct,
        (100.0*missing_fields/NULLIF(fields_checked,0)<=60) AS should_keep
 FROM missing
)
SELECT count(*) AS raw_respondents,
       count(*) FILTER (WHERE should_keep) AS should_keep,
       count(*) FILTER (WHERE NOT should_keep) AS should_remove,
       count(*) FILTER (WHERE should_keep AND s.respondent_id IS NULL) AS incorrectly_removed,
       count(*) FILTER (WHERE NOT should_keep AND s.respondent_id IS NOT NULL) AS incorrectly_retained,
       count(s.respondent_id) AS actually_retained
FROM classified c LEFT JOIN survey.respondents s USING(respondent_id);

-- 06. Main research variable: AI trust completeness, before and after
SELECT 'raw_all' AS population, count(*) AS respondents,
       count(*) FILTER (WHERE nullif(btrim(ai_trust),'') IS NOT NULL) AS ai_trust_answered,
       round(100.0*count(*) FILTER (WHERE nullif(btrim(ai_trust),'') IS NOT NULL)/nullif(count(*),0),2) AS pct
FROM raw.respondents
UNION ALL
SELECT 'survey_retained',count(*),
       count(*) FILTER (WHERE nullif(btrim(raw.ai_trust),'') IS NOT NULL),
       round(100.0*count(*) FILTER (WHERE nullif(btrim(raw.ai_trust),'') IS NOT NULL)/nullif(count(*),0),2)
FROM survey.respondents s JOIN raw.respondents raw ON s.respondent_id=raw.respondent_id::INTEGER;

-- 07. NULL rates for actual cleaned respondent and work columns
WITH cell_values AS (
 SELECT 'respondents' AS table_name, x.key AS column_name, x.value AS value
 FROM survey.respondents r CROSS JOIN LATERAL jsonb_each_text(to_jsonb(r)) x(key,value)
 UNION ALL
 SELECT 'work_info',x.key,x.value
 FROM survey.work_info w CROSS JOIN LATERAL jsonb_each_text(to_jsonb(w)) x(key,value)
)
SELECT table_name,column_name,count(*) AS rows_total,
       count(*) FILTER (WHERE value IS NULL OR btrim(value)='') AS missing_count,
       round(100.0*count(*) FILTER (WHERE value IS NULL OR btrim(value)='')/nullif(count(*),0),2) AS missing_pct
FROM cell_values
GROUP BY table_name,column_name ORDER BY table_name,column_name;

-- 08. Functional duplicate checks not fully enforced by the primary keys.
SELECT 'respondent + question + option duplicated' AS test, count(*) AS violating_groups
FROM (
 SELECT respondent_id,question_code,option_id FROM survey.answers
 WHERE option_id IS NOT NULL
 GROUP BY respondent_id,question_code,option_id HAVING count(*)>1
) d
UNION ALL
SELECT 'respondent + scalar question duplicated',count(*) FROM (
 SELECT respondent_id,question_code FROM survey.answers
 WHERE option_id IS NULL AND item_id IS NULL
 GROUP BY respondent_id,question_code HAVING count(*)>1
) d
UNION ALL
SELECT 'respondent + matrix item duplicated',count(*) FROM (
 SELECT respondent_id,question_code,item_id FROM survey.answers
 WHERE item_id IS NOT NULL AND option_id IS NULL
 GROUP BY respondent_id,question_code,item_id HAVING count(*)>1
) d;

-- 09. Inconsistency between declared question type and actual answers
SELECT q.question_code,q.question_type,count(*) AS n_answers,
       count(*) FILTER (WHERE a.option_id IS NOT NULL) AS n_option,
       count(*) FILTER (WHERE a.numeric_value IS NOT NULL) AS n_numeric,
       count(*) FILTER (WHERE a.text_value IS NOT NULL) AS n_text,
       count(*) FILTER (WHERE a.item_id IS NOT NULL) AS n_matrix_items
FROM survey.questions q JOIN survey.answers a USING(question_code)
GROUP BY q.question_code,q.question_type
HAVING (q.question_type='numeric' AND count(*) FILTER (WHERE a.numeric_value IS NULL)>0)
    OR (q.question_type='multi' AND count(*) FILTER (WHERE a.option_id IS NULL)>0)
    OR (q.question_type='matrix' AND count(*) FILTER (WHERE a.item_id IS NULL)>0)
    OR (q.question_type='single' AND count(*) FILTER (WHERE a.item_id IS NOT NULL)>0)
ORDER BY n_answers DESC, q.question_code;

-- 10. Potentially unused catalog entries (not a violation: cleaning can create these)
SELECT 'questions without answers' AS category,count(*) AS unused
FROM survey.questions q WHERE NOT EXISTS (
 SELECT 1 FROM survey.answers a WHERE a.question_code=q.question_code)
UNION ALL
SELECT 'answer_options without answers',count(*) FROM survey.answer_options o
WHERE NOT EXISTS (SELECT 1 FROM survey.answers a WHERE a.option_id=o.option_id)
UNION ALL
SELECT 'question_items without answers',count(*) FROM survey.question_items i
WHERE NOT EXISTS (SELECT 1 FROM survey.answers a WHERE a.item_id=i.item_id)
UNION ALL
SELECT 'technologies without used answer_options',count(*) FROM survey.technologies t
WHERE NOT EXISTS (SELECT 1 FROM survey.answer_options o WHERE o.technology_id=t.technology_id);

-- 11. Compare original questions and retained catalog; candidates for design review
SELECT 'original questions missing in survey catalog' AS test,count(*) AS total
FROM raw.questions q LEFT JOIN survey.questions s ON s.question_code=q.question
WHERE s.question_code IS NULL
UNION ALL
SELECT 'survey question codes not in original question catalog',count(*)
FROM survey.questions s LEFT JOIN raw.questions q ON q.question=s.question_code
WHERE q.question IS NULL;

-- 12. Distribution of AI trust before vs after cleaning, including missing.
SELECT COALESCE(NULLIF(btrim(r.ai_trust),''),'(missing)') AS ai_trust_value,
       count(*) AS original_count,
       count(s.respondent_id) AS retained_count,
       round(100.0*count(s.respondent_id)/nullif(count(*),0),2) AS pct_of_group_retained
FROM raw.respondents r LEFT JOIN survey.respondents s
 ON s.respondent_id=r.respondent_id::INTEGER
GROUP BY 1 ORDER BY original_count DESC;

-- 13. Numeric ranges/outliers on retained data (not automatically invalid)
SELECT count(*) AS work_rows,
       min(years_professional) AS years_professional_min,
       max(years_professional) AS years_professional_max,
       min(compensation_local) AS compensation_local_min,
       max(compensation_local) AS compensation_local_max,
       min(comp_usd_yearly) AS comp_usd_min,
       max(comp_usd_yearly) AS comp_usd_max
FROM survey.work_info;

-- 14. Actual question types by frequency (useful for normalization review)
SELECT question_type,count(*) AS questions,
       count(*) FILTER (WHERE EXISTS (
         SELECT 1 FROM survey.answers a WHERE a.question_code=q.question_code)) AS questions_with_answers
FROM survey.questions q GROUP BY question_type ORDER BY question_type;