-- Clean final survey data as part of the SAME ETL transaction.
-- The source tables in raw are deliberately untouched.
-- Rule: remove a respondent if >60% of 145 non-ID columns in
-- raw.respondents are NULL or blank (matching the original profiling).

CREATE TEMP TABLE excluded_respondents ON COMMIT DROP AS
SELECT r.respondent_id::INTEGER AS respondent_id
FROM raw.respondents AS r
CROSS JOIN LATERAL jsonb_each_text(to_jsonb(r) - 'respondent_id') AS f(column_name, value)
GROUP BY r.respondent_id
HAVING 100.0 * COUNT(*) FILTER (
    WHERE f.value IS NULL OR BTRIM(f.value) = ''
) / NULLIF(COUNT(*), 0) > 60;

-- Dependent records must be removed before parent respondents.
DELETE FROM survey.answers a
USING excluded_respondents e
WHERE a.respondent_id = e.respondent_id;

DELETE FROM survey.work_info w
USING excluded_respondents e
WHERE w.respondent_id = e.respondent_id;

DELETE FROM survey.respondents r
USING excluded_respondents e
WHERE r.respondent_id = e.respondent_id;

-- Ensure that every raw respondent has been classified exactly once.
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM survey.respondents)
       + (SELECT COUNT(*) FROM excluded_respondents)
       <> (SELECT COUNT(*) FROM raw.respondents) THEN
        RAISE EXCEPTION 'Cleaning reconciliation failed';
    END IF;
END $$;
