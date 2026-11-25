SELECT a.respondent_id, w.role, COUNT(*) AS task_kinds
FROM survey.answers a
JOIN survey.work_info w ON w.respondent_id = a.respondent_id
WHERE a.question_code = 'tasks_delegated_to_agents'
GROUP BY a.respondent_id, w.role
HAVING COUNT(*) > (
    SELECT AVG(c) FROM (
        SELECT COUNT(*) AS c
        FROM survey.answers
        WHERE question_code = 'tasks_delegated_to_agents'
        GROUP BY respondent_id
    ) per_respondent
)
ORDER BY task_kinds DESC;
