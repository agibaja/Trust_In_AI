SELECT
    w.respondent_id,
    r.country,
    w.currency,
    w.years_professional,
    w.compensation_local,
    w.comp_usd_yearly
FROM survey.work_info w
JOIN survey.respondents r
    ON r.respondent_id = w.respondent_id
WHERE w.years_professional > 60
   OR w.compensation_local > 1000000000
   OR w.comp_usd_yearly > 1000000
ORDER BY w.compensation_local DESC NULLS LAST;