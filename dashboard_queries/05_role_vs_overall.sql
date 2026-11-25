WITH role_stats AS (
    SELECT w.role,
           COUNT(*)           AS respondents,
           SUM(t.trust_score) AS total_score
    FROM survey.v_ai_trust t
    JOIN survey.work_info w ON w.respondent_id = t.respondent_id
    WHERE w.role IS NOT NULL
    GROUP BY w.role
), with_overall AS (
    SELECT role, respondents,
           total_score / respondents                       AS role_avg,
           SUM(total_score) OVER () / SUM(respondents) OVER () AS overall_avg
    FROM role_stats
)
SELECT role, respondents,
       ROUND(role_avg, 2)               AS role_avg,
       ROUND(overall_avg, 2)            AS overall_avg,
       ROUND(role_avg - overall_avg, 2) AS difference
FROM with_overall
WHERE respondents >= %(min_resp)s
ORDER BY difference DESC;
