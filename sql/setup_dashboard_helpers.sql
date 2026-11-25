-- Run AFTER the existing schema + ETL + cleaning. Idempotent.
-- Based on the original answer_codes mapping, not an assumed scoring scale.
CREATE OR REPLACE VIEW survey.v_ai_trust AS
SELECT a.respondent_id,
       c.code::INTEGER AS trust_score,
       a.text_value AS trust_label
FROM survey.answers a
JOIN raw.answer_codes c
  ON c.code_column = 'ai_trust_code'
 AND c.label = a.text_value
WHERE a.question_code = 'ai_trust'
  AND c.code ~ '^[0-4]$';

CREATE OR REPLACE FUNCTION survey.eligible_respondents(
    p_countries TEXT[], 
    p_roles TEXT[], 
    p_age_groups TEXT[],
    p_min_years INTEGER, 
    p_max_years INTEGER
) RETURNS TABLE(respondent_id INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT r.respondent_id
    FROM survey.respondents r
    LEFT JOIN survey.work_info w ON w.respondent_id = r.respondent_id
    WHERE (p_countries IS NULL OR r.country = ANY(p_countries))
      AND (p_roles IS NULL OR w.role = ANY(p_roles))
      AND (p_age_groups IS NULL OR r.age_group = ANY(p_age_groups))
      AND (p_min_years IS NULL OR r.years_coding >= p_min_years)
      AND (p_max_years IS NULL OR r.years_coding <= p_max_years)
$$;
