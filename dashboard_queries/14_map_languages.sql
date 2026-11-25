-- Supporting visualization query for Q14.
-- Keep the original 14_language_ranks.sql unchanged as the assessed query.
-- Rank ALL languages first, then filter the selected language AFTER ranking.
WITH lang_counts AS (
    SELECT r.country, ao.option_text AS language, COUNT(*) AS users
    FROM survey.answers a
    JOIN survey.answer_options ao ON ao.option_id = a.option_id
    JOIN survey.respondents r ON r.respondent_id = a.respondent_id
    JOIN survey.eligible_respondents(
        %(countries)s, %(roles)s, %(age_groups)s,
        %(min_years)s, %(max_years)s
    ) e ON e.respondent_id = a.respondent_id
    WHERE a.question_code = 'languages_used'
      AND r.country IS NOT NULL
    GROUP BY r.country, ao.option_text
), ranked AS (
    SELECT country, language, users,
           RANK() OVER (PARTITION BY country ORDER BY users DESC) AS rank_in_country
    FROM lang_counts
)
SELECT country, language, users, rank_in_country
FROM ranked
WHERE rank_in_country <= %(top_n)s
  AND language = %(language)s
ORDER BY country, rank_in_country;
