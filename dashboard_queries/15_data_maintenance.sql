BEGIN;

-- before
SELECT (SELECT COUNT(*) FROM survey.answers   WHERE respondent_id = 12345) AS answers,
       (SELECT COUNT(*) FROM survey.work_info WHERE respondent_id = 12345) AS work_info,
       (SELECT COUNT(*) FROM survey.respondents WHERE respondent_id = 12345) AS respondents;

-- children first (no ON DELETE CASCADE in the schema)
DELETE FROM survey.answers   WHERE respondent_id = 12345;
DELETE FROM survey.work_info WHERE respondent_id = 12345;
DELETE FROM survey.respondents WHERE respondent_id = 12345;

-- after (all three should be 0)
SELECT (SELECT COUNT(*) FROM survey.answers   WHERE respondent_id = 12345) AS answers,
       (SELECT COUNT(*) FROM survey.work_info WHERE respondent_id = 12345) AS work_info,
       (SELECT COUNT(*) FROM survey.respondents WHERE respondent_id = 12345) AS respondents;

ROLLBACK;   -- Restores all deleted records. No COMMIT, to keep the deletion from being permanent.
