
-- Q14 performance experiment: effect of an index on question_code.
-- Original dashboard query remains unchanged.
-- Both temporary tables contain the same data.
-- One has no index; the other has an index on question_code.

-- 1. Create two identical temporary copies.
CREATE TEMP TABLE answers_q14_no_index AS
SELECT * FROM survey.answers;

CREATE TEMP TABLE answers_q14_with_index AS
SELECT * FROM survey.answers;

-- 2. Add the equivalent of ix_answer_question to only one copy.
CREATE INDEX idx_q14_question_code
ON answers_q14_with_index(question_code);

-- 3. Update statistics so PostgreSQL can choose its execution plan.
ANALYZE answers_q14_no_index;
ANALYZE answers_q14_with_index;


-- 4. Q14 using the table WITHOUT an index.
EXPLAIN (ANALYZE, BUFFERS)
WITH lang_counts AS (
    SELECT
        r.country,
        ao.option_text AS language,
        COUNT(*) AS users
    FROM answers_q14_no_index a
    JOIN survey.answer_options ao
        ON ao.option_id = a.option_id
    JOIN survey.respondents r
        ON r.respondent_id = a.respondent_id
    JOIN survey.eligible_respondents(
        NULL, NULL, NULL, NULL, NULL
    ) e
        ON e.respondent_id = a.respondent_id
    WHERE a.question_code = 'languages_used'
      AND r.country IS NOT NULL
    GROUP BY r.country, ao.option_text
),
ranked AS (
    SELECT
        country,
        language,
        users,
        RANK() OVER (
            PARTITION BY country
            ORDER BY users DESC
        ) AS rank_in_country
    FROM lang_counts
)
SELECT country, language, users, rank_in_country
FROM ranked
WHERE rank_in_country <= 5
ORDER BY country, rank_in_country;


-- 5. Q14 using the table WITH an index.
EXPLAIN (ANALYZE, BUFFERS)
WITH lang_counts AS (
    SELECT
        r.country,
        ao.option_text AS language,
        COUNT(*) AS users
    FROM answers_q14_with_index a
    JOIN survey.answer_options ao
        ON ao.option_id = a.option_id
    JOIN survey.respondents r
        ON r.respondent_id = a.respondent_id
    JOIN survey.eligible_respondents(
        NULL, NULL, NULL, NULL, NULL
    ) e
        ON e.respondent_id = a.respondent_id
    WHERE a.question_code = 'languages_used'
      AND r.country IS NOT NULL
    GROUP BY r.country, ao.option_text
),
ranked AS (
    SELECT
        country,
        language,
        users,
        RANK() OVER (
            PARTITION BY country
            ORDER BY users DESC
        ) AS rank_in_country
    FROM lang_counts
)
SELECT country, language, users, rank_in_country
FROM ranked
WHERE rank_in_country <= 5
ORDER BY country, rank_in_country;
