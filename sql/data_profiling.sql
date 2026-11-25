-- AI Survey 2026: SQL-only data profiling
-- Run against ai_survey AFTER load_raw2db.py has completed.
-- No permanent tables are created or modified. Temporary results last for this session.
-- PostgreSQL executes ALL computations. Use psql -f to see every result.

-- 1. Counts: original six files and seven final entities.
SELECT 'raw' AS schema_name, 'respondents' AS table_name, COUNT(*) AS row_count FROM raw.respondents
UNION ALL SELECT 'raw','ai_trust_ml', COUNT(*) FROM raw.ai_trust_ml
UNION ALL SELECT 'raw','questions', COUNT(*) FROM raw.questions
UNION ALL SELECT 'raw','answer_codes', COUNT(*) FROM raw.answer_codes
UNION ALL SELECT 'raw','multi_select_answers', COUNT(*) FROM raw.multi_select_answers
UNION ALL SELECT 'raw','data_dictionary', COUNT(*) FROM raw.data_dictionary
UNION ALL SELECT 'survey','respondents', COUNT(*) FROM survey.respondents
UNION ALL SELECT 'survey','work_info', COUNT(*) FROM survey.work_info
UNION ALL SELECT 'survey','questions', COUNT(*) FROM survey.questions
UNION ALL SELECT 'survey','question_items', COUNT(*) FROM survey.question_items
UNION ALL SELECT 'survey','technologies', COUNT(*) FROM survey.technologies
UNION ALL SELECT 'survey','answer_options', COUNT(*) FROM survey.answer_options
UNION ALL SELECT 'survey','answers', COUNT(*) FROM survey.answers
ORDER BY 1, 2;

-- 2. Catalog-based check: each of the 7 final tables must have a real PRIMARY KEY.
SELECT t.table_name,
       COALESCE(string_agg(k.column_name, ', ' ORDER BY k.ordinal_position), '(MISSING)') AS primary_key_columns,
       CASE WHEN COUNT(k.column_name)>0 THEN 'PASS' ELSE 'FAIL' END AS pk_status
FROM information_schema.tables t
LEFT JOIN information_schema.table_constraints c
  ON c.table_schema=t.table_schema AND c.table_name=t.table_name
 AND c.constraint_type='PRIMARY KEY'
LEFT JOIN information_schema.key_column_usage k
  ON k.constraint_schema=c.constraint_schema AND k.constraint_name=c.constraint_name
 AND k.table_schema=c.table_schema AND k.table_name=c.table_name
WHERE t.table_schema='survey' AND t.table_type='BASE TABLE'
GROUP BY t.table_name
ORDER BY t.table_name;

-- 3. All constraints and indexes: proof for assignment screenshots.
SELECT conrelid::regclass AS table_name, conname AS constraint_name,
       CASE contype WHEN 'p' THEN 'PRIMARY KEY' WHEN 'f' THEN 'FOREIGN KEY'
         WHEN 'u' THEN 'UNIQUE' WHEN 'c' THEN 'CHECK' ELSE contype::text END AS kind,
       pg_get_constraintdef(oid) AS definition
FROM pg_constraint WHERE connamespace='survey'::regnamespace
ORDER BY 1,3,2;

SELECT tablename AS table_name, indexname, indexdef
FROM pg_indexes WHERE schemaname='survey'
ORDER BY tablename, indexname;

-- 4. Candidate keys on ORIGINAL files (blank IDs count as missing).
-- unique = no duplicate among nonblank key tuples, but a PK also forbids blanks.
CREATE TEMP TABLE profile_keys (
 source_table TEXT, candidate_key TEXT, rows_total BIGINT,
 missing_key BIGINT, distinct_nonmissing BIGINT, duplicate_excess BIGINT
) ON COMMIT PRESERVE ROWS;

INSERT INTO profile_keys
SELECT 'raw.respondents','respondent_id', COUNT(*),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(respondent_id),'') IS NULL),
 COUNT(DISTINCT respondent_id) FILTER (WHERE NULLIF(BTRIM(respondent_id),'') IS NOT NULL),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(respondent_id),'') IS NOT NULL)
   - COUNT(DISTINCT respondent_id) FILTER (WHERE NULLIF(BTRIM(respondent_id),'') IS NOT NULL)
FROM raw.respondents;

INSERT INTO profile_keys
SELECT 'raw.ai_trust_ml','respondent_id', COUNT(*),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(respondent_id),'') IS NULL),
 COUNT(DISTINCT respondent_id) FILTER (WHERE NULLIF(BTRIM(respondent_id),'') IS NOT NULL),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(respondent_id),'') IS NOT NULL)
   - COUNT(DISTINCT respondent_id) FILTER (WHERE NULLIF(BTRIM(respondent_id),'') IS NOT NULL)
FROM raw.ai_trust_ml;

INSERT INTO profile_keys
SELECT 'raw.questions','question',COUNT(*),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(question),'') IS NULL),
 COUNT(DISTINCT question) FILTER (WHERE NULLIF(BTRIM(question),'') IS NOT NULL),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(question),'') IS NOT NULL)
  - COUNT(DISTINCT question) FILTER (WHERE NULLIF(BTRIM(question),'') IS NOT NULL)
FROM raw.questions;

INSERT INTO profile_keys
SELECT 'raw.answer_codes','(code_column, code)',COUNT(*),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(code_column),'') IS NULL OR NULLIF(BTRIM(code),'') IS NULL),
 COUNT(DISTINCT (code_column,code)) FILTER (WHERE NULLIF(BTRIM(code_column),'') IS NOT NULL AND NULLIF(BTRIM(code),'') IS NOT NULL),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(code_column),'') IS NOT NULL AND NULLIF(BTRIM(code),'') IS NOT NULL)
 - COUNT(DISTINCT (code_column,code)) FILTER (WHERE NULLIF(BTRIM(code_column),'') IS NOT NULL AND NULLIF(BTRIM(code),'') IS NOT NULL)
FROM raw.answer_codes;

INSERT INTO profile_keys
SELECT 'raw.multi_select_answers','(respondent_id, question, answer)',COUNT(*),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(respondent_id),'') IS NULL OR NULLIF(BTRIM(question),'') IS NULL OR NULLIF(BTRIM(answer),'') IS NULL),
 COUNT(DISTINCT (respondent_id,question,answer)) FILTER
  (WHERE NULLIF(BTRIM(respondent_id),'') IS NOT NULL AND NULLIF(BTRIM(question),'') IS NOT NULL AND NULLIF(BTRIM(answer),'') IS NOT NULL),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(respondent_id),'') IS NOT NULL AND NULLIF(BTRIM(question),'') IS NOT NULL AND NULLIF(BTRIM(answer),'') IS NOT NULL)
 - COUNT(DISTINCT (respondent_id,question,answer)) FILTER
  (WHERE NULLIF(BTRIM(respondent_id),'') IS NOT NULL AND NULLIF(BTRIM(question),'') IS NOT NULL AND NULLIF(BTRIM(answer),'') IS NOT NULL)
FROM raw.multi_select_answers;

INSERT INTO profile_keys
SELECT 'raw.data_dictionary','(file, column)',COUNT(*),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(file),'') IS NULL OR NULLIF(BTRIM("column"),'') IS NULL),
 COUNT(DISTINCT (file,"column")) FILTER (WHERE NULLIF(BTRIM(file),'') IS NOT NULL AND NULLIF(BTRIM("column"),'') IS NOT NULL),
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(file),'') IS NOT NULL AND NULLIF(BTRIM("column"),'') IS NOT NULL)
 - COUNT(DISTINCT (file,"column")) FILTER (WHERE NULLIF(BTRIM(file),'') IS NOT NULL AND NULLIF(BTRIM("column"),'') IS NOT NULL)
FROM raw.data_dictionary;

SELECT *, CASE WHEN missing_key=0 AND duplicate_excess=0 THEN 'VALID CANDIDATE KEY' ELSE 'REVIEW' END AS assessment
FROM profile_keys ORDER BY source_table;

-- 5. Missing values in EVERY COLUMN of the SIX ORIGINAL FILES.
-- Dynamic SQL constructs one aggregate scan per file; no pandas computations.
CREATE TEMP TABLE profile_nulls (
 source_table TEXT, column_name TEXT, null_or_blank_count BIGINT, total_rows BIGINT,
 null_or_blank_pct NUMERIC(7,3)
) ON COMMIT PRESERVE ROWS;
DO $$
DECLARE tbl TEXT; expr TEXT; n BIGINT[]; total BIGINT; cols TEXT[]; i INT;
BEGIN
 FOR tbl IN SELECT unnest(ARRAY['respondents','ai_trust_ml','questions','answer_codes','multi_select_answers','data_dictionary']) LOOP
  SELECT array_agg(column_name ORDER BY ordinal_position),
         string_agg(format('COUNT(*) FILTER (WHERE %I IS NULL OR BTRIM(%I) = '''')',column_name,column_name), ', ' ORDER BY ordinal_position)
    INTO cols,expr
  FROM information_schema.columns WHERE table_schema='raw' AND table_name=tbl;
  EXECUTE format('SELECT ARRAY[%s]::bigint[], COUNT(*) FROM raw.%I',expr,tbl) INTO n,total;
  FOR i IN 1..array_length(cols,1) LOOP
   INSERT INTO profile_nulls VALUES ('raw.'||tbl,cols[i],n[i],total,
    CASE WHEN total>0 THEN ROUND(n[i]*100.0/total,3) ELSE NULL END);
  END LOOP;
 END LOOP;
END $$;

-- The following SELECT exports the full per-column missing-value results.
SELECT source_table, column_name, null_or_blank_count, total_rows, null_or_blank_pct
FROM profile_nulls ORDER BY source_table, column_name;

-- 6. Referential integrity / completeness of mappings.
SELECT 'raw multi-select respondent_id not in raw respondents' AS test, COUNT(*) AS violations
FROM raw.multi_select_answers a LEFT JOIN raw.respondents r ON a.respondent_id=r.respondent_id
WHERE r.respondent_id IS NULL
UNION ALL
SELECT 'raw ML respondent_id not in raw respondents',COUNT(*)
FROM raw.ai_trust_ml a LEFT JOIN raw.respondents r ON a.respondent_id=r.respondent_id
WHERE r.respondent_id IS NULL
UNION ALL
SELECT 'raw multi-select question not in raw questions',COUNT(*)
FROM raw.multi_select_answers a LEFT JOIN raw.questions q ON a.question=q.question
WHERE q.question IS NULL
UNION ALL
SELECT 'final answers with missing respondent',COUNT(*)
FROM survey.answers a LEFT JOIN survey.respondents r ON a.respondent_id=r.respondent_id
WHERE r.respondent_id IS NULL
UNION ALL
SELECT 'final answers with missing question',COUNT(*)
FROM survey.answers a LEFT JOIN survey.questions q ON a.question_code=q.question_code
WHERE q.question_code IS NULL;

-- 7. Coverage and potential information loss from transforming the files.
SELECT 'original respondents' AS metric, COUNT(*) AS value FROM raw.respondents
UNION ALL SELECT 'final respondents',COUNT(*) FROM survey.respondents
UNION ALL SELECT 'raw multi-select selections excluding admired',COUNT(*)
 FROM raw.multi_select_answers WHERE question NOT LIKE '%\_admired' ESCAPE '\'
UNION ALL SELECT 'final option-based answer rows',COUNT(*) FROM survey.answers WHERE option_id IS NOT NULL
UNION ALL SELECT 'raw scalar input rows',COUNT(*) FROM raw.scalar_answers
UNION ALL SELECT 'final scalar answer rows',COUNT(*) FROM survey.answers WHERE option_id IS NULL;

-- 8. Numerical range/format checks on selected source columns.
-- Use numeric regex guards before CAST; profiling must not crash on nonnumeric strings.
SELECT 'years_coding' AS field,
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(years_coding),'') IS NOT NULL AND BTRIM(years_coding) !~ '^[+-]?[0-9]+$') AS invalid_format,
 MIN(years_coding::NUMERIC) FILTER (WHERE BTRIM(years_coding) ~ '^[+-]?[0-9]+$') AS min_value,
 MAX(years_coding::NUMERIC) FILTER (WHERE BTRIM(years_coding) ~ '^[+-]?[0-9]+$') AS max_value
FROM raw.respondents
UNION ALL
SELECT 'years_professional',
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(years_professional),'') IS NOT NULL AND BTRIM(years_professional) !~ '^[+-]?[0-9]+$'),
 MIN(years_professional::NUMERIC) FILTER (WHERE BTRIM(years_professional) ~ '^[+-]?[0-9]+$'),
 MAX(years_professional::NUMERIC) FILTER (WHERE BTRIM(years_professional) ~ '^[+-]?[0-9]+$')
FROM raw.respondents
UNION ALL
SELECT 'compensation_local',
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(compensation_local),'') IS NOT NULL AND BTRIM(compensation_local) !~ '^[+-]?[0-9]+(\.[0-9]+)?$'),
 MIN(compensation_local::NUMERIC) FILTER (WHERE BTRIM(compensation_local) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'),
 MAX(compensation_local::NUMERIC) FILTER (WHERE BTRIM(compensation_local) ~ '^[+-]?[0-9]+(\.[0-9]+)?$')
FROM raw.respondents
UNION ALL
SELECT 'comp_usd_yearly',
 COUNT(*) FILTER (WHERE NULLIF(BTRIM(comp_usd_yearly),'') IS NOT NULL AND BTRIM(comp_usd_yearly) !~ '^[+-]?[0-9]+(\.[0-9]+)?$'),
 MIN(comp_usd_yearly::NUMERIC) FILTER (WHERE BTRIM(comp_usd_yearly) ~ '^[+-]?[0-9]+(\.[0-9]+)?$'),
 MAX(comp_usd_yearly::NUMERIC) FILTER (WHERE BTRIM(comp_usd_yearly) ~ '^[+-]?[0-9]+(\.[0-9]+)?$')
FROM raw.respondents;

-- 9. Unexpected values/codes: categorical source values without dictionary mapping.
SELECT r.age_group_code, r.age_group, COUNT(*) AS records
FROM raw.respondents r
LEFT JOIN raw.answer_codes c
 ON c.code_column='age_group_code' AND c.code=r.age_group_code AND c.label=r.age_group
WHERE NULLIF(BTRIM(r.age_group_code),'') IS NOT NULL AND c.code IS NULL
GROUP BY r.age_group_code,r.age_group ORDER BY records DESC LIMIT 30;

-- 10. Date/time fields: discover availability (do not invent date ranges).
SELECT table_name, column_name, data_type
FROM information_schema.columns
WHERE table_schema='raw'
 AND (column_name ~* '(date|time|timestamp|year)' OR data_type IN ('date','timestamp without time zone','timestamp with time zone','time without time zone'))
ORDER BY table_name,column_name;

-- 11. Missingness/duplicates do NOT by themselves establish semantic nonresponse.
-- Example: respondents without a selected option for one specific question.
SELECT COUNT(*) AS respondents_without_recorded_agent_selection
FROM survey.respondents r
WHERE NOT EXISTS (
 SELECT 1 FROM survey.answers a
 WHERE a.respondent_id=r.respondent_id
 AND a.question_code='ai_coding_agents_used'
);
