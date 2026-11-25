# Columns retained from respondents.csv; the rest are mapped to survey.answers.
PERSON_COLUMNS = ['respondent_id', 'age_group', 'gender', 'country', 'education', 'coder_type', 'years_coding', 'so_account', 'so_years']
WORK_COLUMNS = ['employment', 'role', 'ic_or_manager', 'work_setting', 'years_professional', 'industry', 'org_size', 'dept_budget_change', 'job_satisfaction', 'currency', 'compensation_local', 'comp_usd_yearly', 'org_ai_use', 'org_ai_approach']
# Flags and codes derived from other answers are intentionally excluded.
EXCLUDED_PREFIXES = ("ai_role_easier_", "ai_role_harder_")
MATRIX_PREFIXES = ("accuracy_importance_", "recency_importance_", "traceability_importance_")
