# Project B — Developer Trust in AI

**Relational database and interactive SQL dashboard**  
**Dataset:** Stack Overflow 2026 — Developer Trust in AI  
**Authors:** Ainhoa Gibaja and Ana Caro Casares

This repository implements a PostgreSQL relational database derived from the Stack Overflow 2026 developer survey, documents SQL-based data profiling and cleaning, and provides an interactive Streamlit application for exploring the resulting data.

## 1. Project structure

The project uses two PostgreSQL schemas:

- **`raw`** preserves the six imported source datasets (and the derived `raw.scalar_answers` staging table).
- **`survey`** holds seven relational tables: `respondents`, `work_info`, `questions`, `question_items`, `technologies`, `answer_options`, and `answers`.

Key files and directories:

```text
projectB/
├── .gitignore
├── README.md
|
├── project_setup.py                # Setup orchestrator, destructive
├── download_data.py                # Download/validate source archive
├── connect_db.py                   # Connect/create PostgreSQL database
├── build_schema.py                 # Create database schemas (destructive)
├── load_raw2db.py                  # Import, transform, and clean data
├── verify_db.py                    # Structural/integrity verification
├── run_sql_file.py                 # Execute an SQL file and export results
├── run_profiling.py                # Original-data profiling
├── run_clean_profiling.py          # Cleaned-data profiling
├── test_dashboard_queries.py       # Parameterized SQL query tests
|
├── dashboard.py                    # Streamlit interface (latest design: v5)
├── db_dashboard.py                 # PostgreSQL connection/query helper
|
├── requirements.txt
|
├── dashboard_queries/
│   ├── 01_demographic.sql
│   ├── 02_respondent_answers_readable.sql
│   ├── 02_respondent_profile.sql
│   ├── 03_trust_distribution.sql
│   ├── ...
│   ├── 13_multilingual_above_average.sql
│   ├── 14_language_ranks.sql
│   ├── 14_map_languages.sql
│   └── 15_data_maintenance.sql
|
├── sql/
│   ├── schema.sql
│   ├── transform.sql
│   ├── filter_respondents.sql
│   ├── setup_dashboard_helpers.sql
│   ├── data_profiling.sql
│   ├── clean_data_profiling.sql
│   ├── analytical_correctness_audit.sql
│   ├── check_outliers.sql
│   ├── diagnostic_08.sql
|   ├── performance_q14.sql
│   ├── row_missingness.sql
│   └── verify.sql
|
└── reports/
    ├── analytical_audit/
    ├── cleaning/
    ├── clean_profiling/
    ├── dashboard_setup/
    ├── language_mismatches/
    ├── outliers/
    ├── profiling/
    ├── q14_performance/
    ├── query_tests/
    └── verification/                     
```

The tree is illustrative: keep all other scripts and SQL files already present in your project. **Once run, do not replace the validated `dashboard_queries/` files with older versions from earlier update packages.**

## 2. Requirements and initial configuration

- Windows with an Anaconda/Miniconda environment, or an equivalent Python environment.
- Running PostgreSQL with a valid connection configuration for the `ai_survey` database.
- The project's connection credentials (locally stored in `password.txt` as expected by the existing scripts).
- Network access for the initial Kaggle download if `archive.zip` is absent.

Activate the environment and enter the **actual** location of the cloned/extracted project and your environment name:

```cmd
conda activate info_tech_env
cd C:\path\to\projectB
python -m pip install -r requirements-dashboard.txt
python -m pip install kagglehub "plotly>=5.18,<7"
```

The dashboard uses Streamlit, Altair, Plotly and psycopg2. Install any additional dependencies declared by the project's scripts. Source Sans Pro is loaded via CSS/Google Fonts when available, with a sans-serif fallback; font binaries are **not** distributed with this repository.

## 3. Complete initialization from scratch

> **Warning:** `build_schema.py` drops and recreates the `raw` and `survey` PostgreSQL schemas. It deletes the existing project tables and the dashboard view/function. Back up any data you want to preserve before running a full rebuild.

Run from the project root, in order:

```cmd
python download_data.py
python connect_db.py
python build_schema.py
python load_raw2db.py

python verify_db.py
python run_profiling.py
python run_clean_profiling.py

python run_sql_file.py sql/setup_dashboard_helpers.sql dashboard_setup
python test_dashboard_queries.py

python -m streamlit run dashboard.py
```

If `sql/analytical_correctness_audit.sql` is included, you can also run it **after creating the dashboard helpers and before launching Streamlit**:

```cmd
python run_sql_file.py sql/analytical_correctness_audit.sql analytical_audit
```

`download_data.py` checks whether `archive.zip` already exists and validates it instead of downloading again. When absent, it retrieves the processed Kaggle dataset and creates the archive required by the ETL. The archive should be generated locally and excluded from Git rather than committed.

The ETL loads the six CSV files into `raw`, reshapes survey responses into relational tables, and applies the respondent-cleaning rule within the ETL transaction. The cleaning rule excludes respondents with **more than 60% missing or blank values across the 145 original non-ID respondent fields**, while retaining original staging data. A previously verified run produced **30,903 raw respondents and 12,825 retained respondents**; these counts should be checked on each fresh build.

### Dashboard SQL helpers

`sql/setup_dashboard_helpers.sql` creates or replaces:

- `survey.v_ai_trust`: exposes an ordinal `trust_score` (0–4), `trust_label`, and respondent identifier; it uses the survey answer-code mappings.
- `survey.eligible_respondents(...)`: applies optional country, job-role, age-group, and minimum/maximum coding-experience filters.

**Run this helper setup again after every full schema rebuild.** It is not sufficient to load the database and launch the dashboard without these objects.

### Optional one-command setup

If your repository includes `project_setup.py`, you may run:

```cmd
python project_setup.py
```

Follow its confirmation prompt: it performs a destructive rebuild. This README's explicit command sequence remains the reference for the order of operations.

## 4. Daily use: run the dashboard without rebuilding

Once the database and helpers exist, there is no reason to rerun the ETL or profiling; simply, to open the interface:

```cmd
conda activate info_tech
cd C:\path\to\projectB
python -m streamlit run dashboard.py
```

The application normally opens at `http://localhost:8501`. PostgreSQL must be running.

## 5. SQL data profiling, verification, and outputs

The analytical calculations are performed by **PostgreSQL**, not pandas. Python runs SQL and presents or exports the returned data.

| Purpose | Command | Output directory |
|---|---|---|
| Database structure/integrity | `python verify_db.py` | See the verification script configuration |
| Original data profiling | `python run_profiling.py` | `reports/profiling/` |
| Cleaned data profiling | `python run_clean_profiling.py` | `reports/clean_profiling/` |
| Dashboard query execution/type checks | `python test_dashboard_queries.py` | `reports/query_tests/` |
| Optional analytical invariants | `python run_sql_file.py sql/analytical_correctness_audit.sql analytical_audit` | `reports/analytical_audit/` |

The original profiling covers source and final record counts; final-table keys, constraints, and indexes; candidate-key uniqueness in the six source datasets; missing or blank values for every raw column; and foreign-key/reference checks. Additional checks in the source SQL include reconciliation, numeric format/range inspection, answer-code mapping, and survey-response coverage. **The exact exported result files depend on the profiling SQL and runner version actually executed**; do not claim a check ran unless it appears in the output.

The `raw` tables intentionally remain source/staging data rather than being given artificial primary keys; all seven final `survey` tables have PostgreSQL primary keys. The `raw` snapshots are preserved during respondent cleaning. Missing data do not necessarily mean a respondent deliberately skipped a question: survey routing can also explain absent answers.

`sql/data_profiling.sql` contains temporary tables (`profile_keys` and `profile_nulls`), which exist only for that PostgreSQL session. Use `run_profiling.py`, `psql`, or pgAdmin to execute the profiling SQL. For a direct `psql` run:

```cmd
psql -h localhost -U postgres -d ai_survey -v ON_ERROR_STOP=1 -f sql/data_profiling.sql
```

If `psql` is not on PATH, use its full installation path. The profiling scripts do not intentionally change permanent survey data.

### Analytical correctness and interpretation

`test_dashboard_queries.py` verifies that parameterized queries execute and return expected structures; it does not on its own establish analytical correctness. The optional audit performs independent consistency checks. Some observed findings that should be discussed carefully:

- Valid AI trust scores represent ordered categories **0–4**; an average is a useful descriptive summary but rests on treating ordinal codes numerically.
- Q8 uses two **different denominators**: `pct_with_ai` divides respondents reporting both a language and AI-assisted use by respondents reporting that language, while `pct_unmatched_ai` divides unmatched AI-assisted selections by all AI-assisted selections for that language. These percentages are **not complements**.
- A mismatch between language-use and AI-assisted-language answers is not, by itself, evidence that a respondent considers themselves unable to program in that language.
- Q11 compares trust averages across AI-use categories; this is not a standalone computation of a correlation coefficient.

## 6. Streamlit dashboard

The app has five **top-navigation** sections:

1. **Respondents** — Q1–Q2: demographic distribution, country map where applicable, and readable individual respondent profiles.
2. **Trust in AI** — Q3–Q7: trust distribution, role averages, deviations from the overall average, experience buckets, and trust segments.
3. **AI adoption and usage** — Q8–Q11: AI-assisted language shares and mismatches, agent tools, delegated tasks, and AI usage versus trust.
4. **Technology landscape** — Q12–Q14: database retention, number of languages, and language rankings by country.
5. **Data maintenance** — Q15: a controlled deletion demonstration using a transaction that is rolled back.

Visualizations include bar charts, donut/pie charts, line graphs, scatter/bubble charts, SQL-backed discrete histograms, and country maps. Not every visualization is applicable to every query. Histogram frequency calculations are in `10_task_kind_histogram.sql` and `13_language_count_histogram.sql`, without using pandas as an analytical processing layer. Q2 and Q14 also have helper queries for visualization, `02_respondent_answers_readable.sql` and `14_map_languages.sql` respectively.

### Current visual conventions (v5)

- Blue-themed design inspired by the team's presentation, with **Source Sans Pro Regular**, a gradient title banner, and top navigation. Original presentation template can be found via [SlidesCarnival](https://www.slidescarnival.com/template/modern-pitch-deck/30817).

- Complete research questions are used as headings. Advanced-query asterisks were removed from the interface headings; the report may retain that notation.
- The SQL text appears **below** each chart, followed by the result preview. Q2 and Q15 show SQL below their interaction because they do not have conventional charts the way other queries do.
- Q2 shows human-readable question text from `survey.questions.question_text`; multiple answers for one question are grouped together and empty answer values are suppressed in the readable view. The original SQL results remain available.
- Trust **average** charts use a consistent **Y-axis range of 0–4**, where appropriate. Difference-from-average charts retain negative values, displayed in **red**; nonnegative bars are blue.
- Ordinal/numeric X-axis categories use their natural ascending order (trust scores, age ranges, experience ranges, discrete histogram counts). Countries and programming languages may be ordered by frequency or the query's selected ranking.
- Q3's two charts use aligned heights. Bubble plots for Q8, Q9, and Q12 show item names and use color and bubble size to convey additional metrics; hover details and label-density controls improve readability.
- Q1's **age groups use a bar chart** rather than a pie chart. The geographic views are shown for country-based analyses; some nonstandard country names may not resolve on a map.


### Filters and security

A demographic selector is implemented using an explicit allowlist of permissible SQL column identifiers; other input values use psycopg2 parameters. The UI executes read-only analytical queries. For Q15, deletion statements are performed inside a controlled transaction and **always rolled back**; they do not permanently delete respondents.

Demographic filters affect the queries that explicitly invoke `survey.eligible_respondents` (previously verified for Q3, Q4, Q6, Q7, Q9, Q11, Q12, and Q14). **Do not assume global filters change all other queries**; Q5, Q8, Q10, and Q13 use the populations defined by their own SQL.

## 7. Updating files safely

The dashboard's appearance can be changed independently from the database and queries. For visual-only updates, replace **`dashboard.py`**; do not overwrite your tested SQL files or rerun the ETL.

Keep secrets and locally generated artifacts out of source control, including `password.txt`, `archive.zip`, and unnecessary generated data/report files. Do not commit proprietary or unverified download credentials.