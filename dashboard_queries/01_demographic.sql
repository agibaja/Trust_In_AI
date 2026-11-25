-- {col} is filled from a fixed whitelist using psycopg2.sql.Identifier
SELECT {col} AS category, COUNT(*) AS respondents
FROM survey.respondents
WHERE {col} IS NOT NULL
GROUP BY {col}
ORDER BY respondents DESC;
