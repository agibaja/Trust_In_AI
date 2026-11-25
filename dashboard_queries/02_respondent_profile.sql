SELECT r.respondent_id, r.age_group, r.gender, r.country, r.education, r.coder_type,
       w.role, w.industry, w.org_size,
       q.topic, q.question_code, q.question_text, qi.item_code,
       ao.option_text, t.technology_name, a.numeric_value, a.text_value
FROM survey.respondents r
LEFT JOIN survey.work_info w       ON w.respondent_id = r.respondent_id
LEFT JOIN survey.answers a         ON a.respondent_id = r.respondent_id
LEFT JOIN survey.questions q       ON q.question_code = a.question_code
LEFT JOIN survey.question_items qi ON qi.item_id = a.item_id
LEFT JOIN survey.answer_options ao ON ao.option_id = a.option_id
LEFT JOIN survey.technologies t    ON t.technology_id = ao.technology_id
WHERE r.respondent_id = %(respondent_id)s
ORDER BY q.topic, q.question_code;
