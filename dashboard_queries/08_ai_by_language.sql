-- Q8. AI-assisted language use and unmatched AI-assisted selections.
-- %(min_users)s is provided by the dashboard/test runner.
-- Mismatch denominator: all respondents selecting the language in languages_with_ai.
WITH used AS (
    SELECT DISTINCT a.respondent_id, ao.option_text AS language
    FROM survey.answers a
    JOIN survey.answer_options ao ON ao.option_id = a.option_id
    WHERE a.question_code = 'languages_used'
), with_ai AS (
    SELECT DISTINCT a.respondent_id, ao.option_text AS language
    FROM survey.answers a
    JOIN survey.answer_options ao ON ao.option_id = a.option_id
    WHERE a.question_code = 'languages_with_ai'
), used_counts AS (
    SELECT u.language,
           COUNT(*) AS users,
           COUNT(w.respondent_id) AS users_with_ai
    FROM used u
    LEFT JOIN with_ai w
      ON w.respondent_id = u.respondent_id
     AND w.language = u.language
    GROUP BY u.language
), ai_counts AS (
    SELECT w.language,
           COUNT(*) AS ai_language_selections,
           COUNT(*) FILTER (WHERE u.respondent_id IS NULL) AS unmatched_ai_selections
    FROM with_ai w
    LEFT JOIN used u
      ON u.respondent_id = w.respondent_id
     AND u.language = w.language
    GROUP BY w.language
), rates AS (
    SELECT uc.language,
           uc.users,
           uc.users_with_ai,
           ROUND(100.0 * uc.users_with_ai / NULLIF(uc.users, 0), 1) AS pct_with_ai,
           COALESCE(ac.ai_language_selections, 0) AS ai_language_selections,
           COALESCE(ac.unmatched_ai_selections, 0) AS unmatched_ai_selections,
           ROUND(100.0 * COALESCE(ac.unmatched_ai_selections, 0)
                 / NULLIF(ac.ai_language_selections, 0), 1) AS pct_unmatched_ai
    FROM used_counts uc
    LEFT JOIN ai_counts ac ON ac.language = uc.language
    WHERE uc.users >= %(min_users)s
)
SELECT language, users, users_with_ai, pct_with_ai,
       ai_language_selections, unmatched_ai_selections, pct_unmatched_ai,
       RANK() OVER (ORDER BY pct_with_ai DESC NULLS LAST) AS rank_by_share
FROM rates
ORDER BY rank_by_share, language;
