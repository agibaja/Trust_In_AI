WITH used AS (
    SELECT DISTINCT
        a.respondent_id,
        ao.option_text AS language
    FROM survey.answers a
    JOIN survey.answer_options ao
        ON ao.option_id = a.option_id
    WHERE a.question_code = 'languages_used'
),
with_ai AS (
    SELECT DISTINCT
        a.respondent_id,
        ao.option_text AS language
    FROM survey.answers a
    JOIN survey.answer_options ao
        ON ao.option_id = a.option_id
    WHERE a.question_code = 'languages_with_ai'
)
SELECT
    w.language,
    COUNT(*) AS unmatched_selections,
    COUNT(DISTINCT w.respondent_id) AS respondents
FROM with_ai w
LEFT JOIN used u
    ON u.respondent_id = w.respondent_id
   AND u.language = w.language
WHERE u.respondent_id IS NULL
GROUP BY w.language
ORDER BY unmatched_selections DESC;