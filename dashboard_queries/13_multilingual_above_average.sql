SELECT l.respondent_id, r.country, l.languages
FROM (
    SELECT respondent_id, COUNT(*) AS languages
    FROM survey.answers
    WHERE question_code = 'languages_used'
    GROUP BY respondent_id
) l
JOIN survey.respondents r ON r.respondent_id = l.respondent_id
WHERE l.languages > (
    SELECT AVG(c) FROM (
        SELECT COUNT(*) AS c
        FROM survey.answers
        WHERE question_code = 'languages_used'
        GROUP BY respondent_id
    ) x
)
ORDER BY l.languages DESC;
