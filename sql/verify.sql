-- Run in pgAdmin after load (all calculations execute in PostgreSQL).
SELECT 'respondents' AS table_name,COUNT(*) FROM survey.respondents
UNION ALL SELECT 'work_info',COUNT(*) FROM survey.work_info
UNION ALL SELECT 'questions',COUNT(*) FROM survey.questions
UNION ALL SELECT 'question_items',COUNT(*) FROM survey.question_items
UNION ALL SELECT 'technologies',COUNT(*) FROM survey.technologies
UNION ALL SELECT 'answer_options',COUNT(*) FROM survey.answer_options
UNION ALL SELECT 'answers',COUNT(*) FROM survey.answers;

-- No missing respondent references should remain.
SELECT COUNT(*) AS orphan_answers FROM survey.answers a
LEFT JOIN survey.respondents r ON r.respondent_id=a.respondent_id
WHERE r.respondent_id IS NULL;

-- Inspect constraints in pgAdmin's catalog.
SELECT conrelid::regclass AS table_name, conname, contype
FROM pg_constraint WHERE connamespace='survey'::regnamespace
ORDER BY 1,2;

-- Raw file counts for report.
SELECT 'respondents.csv' AS file,COUNT(*) FROM raw.respondents
UNION ALL SELECT 'ai_trust_ml.csv', COUNT(*) FROM raw.ai_trust_ml
UNION ALL SELECT 'questions.csv', COUNT(*) FROM raw.questions
UNION ALL SELECT 'answer_codes.csv', COUNT(*) FROM raw.answer_codes
UNION ALL SELECT 'multi_select_answers.csv', COUNT(*) FROM raw.multi_select_answers
UNION ALL SELECT 'data_dictionary.csv', COUNT(*) FROM raw.data_dictionary;
