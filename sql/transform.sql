-- Populates the seven final tables from the pre-existing raw tables.
-- Run within the ETL transaction only, after COPY.

INSERT INTO survey.respondents
SELECT respondent_id::INTEGER, NULLIF(age_group,''), NULLIF(gender,''),
 NULLIF(country,''),NULLIF(education,''),NULLIF(coder_type,''),
 NULLIF(years_coding,'')::INTEGER,NULLIF(so_account,''),NULLIF(so_years,'')
FROM raw.respondents;

INSERT INTO survey.work_info
SELECT
   respondent_id::INTEGER,
   NULLIF(employment, ''),
   NULLIF(role, ''),
   NULLIF(ic_or_manager, ''),
   NULLIF(work_setting, ''),
   NULLIF(years_professional, '')::INTEGER,
   NULLIF(industry, ''),
   NULLIF(org_size, ''),
   NULLIF(dept_budget_change, ''),
   NULLIF(job_satisfaction, '')::INTEGER,
   NULLIF(currency, ''),
   NULLIF(compensation_local, '')::NUMERIC,
   NULLIF(comp_usd_yearly, '')::NUMERIC,
   NULLIF(org_ai_use, ''),
   NULLIF(org_ai_approach, '')
FROM raw.respondents;

-- Multi-select catalog: exclude 'admired' because it is the intersection of used/wanted.
INSERT INTO survey.questions (question_code,source_column,question_text,question_type,topic)
SELECT question, NULLIF(source_column,''),
 COALESCE(NULLIF(question_text,''),question),
 CASE WHEN question_type = 'Matrix' THEN 'multi' ELSE 'multi' END,
 split_part(question,'_',1)
FROM raw.questions
WHERE question NOT LIKE '%\_admired' ESCAPE '\'
ON CONFLICT(question_code) DO NOTHING;

-- Scalar questions and matrices from the transformed input stream.
INSERT INTO survey.questions (question_code,source_column,question_text,question_type,topic)
SELECT DISTINCT s.question_code,
 d.source_column,
 COALESCE(NULLIF(d.description,''), s.question_code),
 CASE WHEN s.item_code IS NOT NULL THEN 'matrix'
      WHEN d.type IN ('integer','float') THEN 'numeric'
      ELSE 'single' END,
 split_part(s.question_code,'_',1)
FROM raw.scalar_answers s
LEFT JOIN raw.data_dictionary d
 ON d.file='respondents.csv' AND d.column =
    CASE WHEN s.item_code IS NULL THEN s.question_code ELSE s.question_code || '_' || s.item_code END
ON CONFLICT(question_code) DO NOTHING;

-- Matrix item definitions.
INSERT INTO survey.question_items(question_code,item_code)
SELECT DISTINCT question_code,item_code FROM raw.scalar_answers
WHERE item_code IS NOT NULL;

-- Distinct choices for multi-select questions.
INSERT INTO survey.answer_options(question_code,option_text)
SELECT DISTINCT question,answer
FROM raw.multi_select_answers
WHERE question NOT LIKE '%\_admired' ESCAPE '\'
  AND question IS NOT NULL AND answer IS NOT NULL;

-- Technology labels only from technology-related survey options.
INSERT INTO survey.technologies(technology_name,technology_category)
SELECT DISTINCT option_text,
 CASE WHEN question_code LIKE '%coding_agents%' THEN 'coding_agent'
      WHEN question_code LIKE '%llm%' THEN 'llm'
      WHEN question_code LIKE '%database%' THEN 'database'
      ELSE 'technology' END
FROM survey.answer_options
WHERE question_code LIKE '%coding_agents%'
   OR question_code LIKE '%llm%'
   OR question_code LIKE '%database%';

UPDATE survey.answer_options ao
SET technology_id=t.technology_id
FROM survey.technologies t
WHERE ao.option_text=t.technology_name
  AND t.technology_category =
     CASE WHEN ao.question_code LIKE '%coding_agents%' THEN 'coding_agent'
          WHEN ao.question_code LIKE '%llm%' THEN 'llm'
          WHEN ao.question_code LIKE '%database%' THEN 'database'
          ELSE 'technology' END;

-- One row per actual multi-selection.
INSERT INTO survey.answers(respondent_id,question_code,option_id)
SELECT m.respondent_id::INTEGER,m.question,ao.option_id
FROM raw.multi_select_answers m
JOIN survey.answer_options ao
 ON ao.question_code=m.question AND ao.option_text=m.answer
WHERE m.question NOT LIKE '%\_admired' ESCAPE '\';

-- Numeric scalar responses: no Python calculations.
INSERT INTO survey.answers(respondent_id,question_code,item_id,numeric_value)
SELECT s.respondent_id,s.question_code,qi.item_id,s.raw_value::NUMERIC
FROM raw.scalar_answers s
LEFT JOIN survey.question_items qi
 ON qi.question_code=s.question_code AND qi.item_code=s.item_code
JOIN raw.data_dictionary d ON d.file='respondents.csv'
 AND d.column=CASE WHEN s.item_code IS NULL THEN s.question_code ELSE s.question_code || '_' || s.item_code END
WHERE d.type IN ('integer','float');

-- Text scalar responses (including categorical survey responses).
INSERT INTO survey.answers(respondent_id,question_code,item_id,text_value)
SELECT s.respondent_id,s.question_code,qi.item_id,s.raw_value
FROM raw.scalar_answers s
LEFT JOIN survey.question_items qi
 ON qi.question_code=s.question_code AND qi.item_code=s.item_code
JOIN raw.data_dictionary d ON d.file='respondents.csv'
 AND d.column=CASE WHEN s.item_code IS NULL THEN s.question_code ELSE s.question_code || '_' || s.item_code END
WHERE d.type NOT IN ('integer','float');
