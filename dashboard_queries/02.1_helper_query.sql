CREATE FUNCTION survey.eligible_respondents(
    p_countries  TEXT[],
    p_roles      TEXT[],
    p_age_groups TEXT[],
    p_min_years  INTEGER,
    p_max_years  INTEGER
) RETURNS TABLE (respondent_id INTEGER)
LANGUAGE sql STABLE AS $$
    SELECT r.respondent_id
    FROM survey.respondents r
    LEFT JOIN survey.work_info w ON w.respondent_id = r.respondent_id
    WHERE (p_countries  IS NULL OR r.country   = ANY(p_countries))
      AND (p_roles      IS NULL OR w.role      = ANY(p_roles))
      AND (p_age_groups IS NULL OR r.age_group = ANY(p_age_groups))
      AND (p_min_years  IS NULL OR r.years_coding >= p_min_years)
      AND (p_max_years  IS NULL OR r.years_coding <= p_max_years)
$$;
