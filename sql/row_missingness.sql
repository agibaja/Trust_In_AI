WITH respondent_missingness AS (
    SELECT
        r.respondent_id,

        COUNT(*) AS total_columns,

        COUNT(*) FILTER (
            WHERE value IS NULL
               OR BTRIM(value) = ''
        ) AS missing_columns

    FROM raw.respondents r

    CROSS JOIN LATERAL jsonb_each_text(
        to_jsonb(r) - 'respondent_id'
    ) AS fields(column_name, value)

    GROUP BY r.respondent_id
),

missingness_percentage AS (
    SELECT
        respondent_id,
        total_columns,
        missing_columns,

        ROUND(
            100.0 * missing_columns
            / NULLIF(total_columns, 0),
            2
        ) AS missing_pct

    FROM respondent_missingness
)

SELECT
    COUNT(*) AS total_respondents,

    COUNT(*) FILTER (
        WHERE missing_pct <= 60
    ) AS respondents_kept,

    COUNT(*) FILTER (
        WHERE missing_pct > 60
    ) AS respondents_removed,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE missing_pct > 60
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS percentage_removed

FROM missingness_percentage;

WITH missingness AS (
    SELECT
        r.respondent_id,
        100.0 * COUNT(*) FILTER (
            WHERE value IS NULL OR BTRIM(value) = ''
        ) / NULLIF(COUNT(*), 0) AS missing_pct
    FROM raw.respondents r
    CROSS JOIN LATERAL jsonb_each_text(
        to_jsonb(r) - 'respondent_id'
    ) AS x(column_name, value)
    GROUP BY r.respondent_id
)

SELECT
    CASE
        WHEN m.missing_pct <= 60 THEN 'Kept'
        ELSE 'Removed'
    END AS group_name,

    COUNT(*) AS respondents,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(r.ai_trust), '') IS NOT NULL
    ) AS ai_trust_answered,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE NULLIF(BTRIM(r.ai_trust), '') IS NOT NULL
        ) / COUNT(*),
        2
    ) AS ai_trust_response_pct

FROM raw.respondents r

JOIN missingness m
    ON r.respondent_id = m.respondent_id

GROUP BY group_name
ORDER BY group_name;