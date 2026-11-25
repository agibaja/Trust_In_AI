-- Presentation helper for Q2. Keep 02_respondent_profile.sql unchanged.
-- Group one respondent's multiple answers in PostgreSQL, not in Python.
WITH selections AS (
    SELECT
        a.respondent_id,
        COALESCE(q.topic, 'Other') AS topic,
        q.question_code,
        COALESCE(NULLIF(BTRIM(q.question_text), ''), q.question_code) AS question,
        CASE
            WHEN qi.item_code IS NOT NULL AND BTRIM(qi.item_code) <> ''
            THEN qi.item_code || ': ' || COALESCE(
                NULLIF(BTRIM(ao.option_text), ''),
                NULLIF(BTRIM(a.text_value), ''),
                a.numeric_value::TEXT
            )
            ELSE COALESCE(
                NULLIF(BTRIM(ao.option_text), ''),
                NULLIF(BTRIM(a.text_value), ''),
                a.numeric_value::TEXT
            )
        END AS answer
    FROM survey.answers a
    JOIN survey.questions q ON q.question_code = a.question_code
    LEFT JOIN survey.question_items qi ON qi.item_id = a.item_id
    LEFT JOIN survey.answer_options ao ON ao.option_id = a.option_id
    WHERE a.respondent_id = %(respondent_id)s
)
SELECT
    topic,
    question,
    STRING_AGG(DISTINCT answer, ' · ' ORDER BY answer) AS answers
FROM selections
WHERE answer IS NOT NULL
GROUP BY topic, question_code, question
ORDER BY topic, question;
