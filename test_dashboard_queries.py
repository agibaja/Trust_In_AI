"""Read-only integration tests for projectB/dashboard_queries, without Streamlit.

Run from projectB: python test_dashboard_queries.py
Uses the existing password.txt and PostgreSQL ai_survey database.
All analytics are executed in PostgreSQL; Python prints sample rows/types only.
"""
import argparse
import csv
import re
from datetime import datetime
from pathlib import Path

import psycopg2
from psycopg2 import sql

BASE = Path(__file__).resolve().parent
PARAMS = {
    "countries": None, "roles": None, "age_groups": None,
    "min_years": None, "max_years": None,
    "min_users": 20, "min_resp": 20, "top_n": 5,
}
ALLOWED_DEMOGRAPHICS = (
    "age_group", "gender", "country", "education", "coder_type",
    "so_account", "so_years", "years_coding",
)
EXPECTED_COLUMNS = {
    "01_demographic": {"category", "respondents"},
    "02_respondent_profile": {"respondent_id", "question_code"},
    "03_trust_distribution": {"trust_score", "trust_label", "respondents"},
    "04_role_trust": {"role", "avg_trust"},
    "05_role_vs_overall": {"role", "difference"},
    "06_experience_buckets": {"bucket", "avg_trust"},
    "07_trust_segments_role": {"segment", "respondents"},
    "07_trust_segments_experience": {"segment", "respondents"},
    "08_ai_by_language": {"language", "users", "pct_with_ai"},
    "09_ai_tools": {"technology_name", "users", "avg_trust"},
    "10_delegated_above_average": {"respondent_id", "task_kinds"},
    "11_usage_vs_trust": {"usage_score", "avg_trust"},
    "12_database_retention": {"technology_name", "users", "pct_keep"},
    "13_multilingual_above_average": {"respondent_id", "languages"},
    "14_language_ranks": {"country", "language", "rank_in_country"},
}


def connection():
    pw = (BASE / "password.txt").read_text(encoding="utf-8").strip()
    return psycopg2.connect(host="localhost", port=5432, dbname="ai_survey",
                            user="postgres", password=pw, connect_timeout=8)


def get_available_types(conn):
    """Useful data-type audit from PostgreSQL itself."""
    with conn.cursor() as cur:
        cur.execute("""
            SELECT table_schema, table_name, column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_schema = 'survey'
            ORDER BY table_name, ordinal_position
        """)
        values = cur.fetchall()
    conn.rollback()
    return values


def prerequisites(conn):
    with conn.cursor() as cur:
        cur.execute("""
            SELECT to_regclass('survey.v_ai_trust') IS NOT NULL,
                   to_regprocedure('survey.eligible_respondents(text[],text[],text[],integer,integer)') IS NOT NULL
        """)
        answer = cur.fetchone()
    conn.rollback()
    return answer


def oid_type(conn, oids):
    with conn.cursor() as cur:
        cur.execute("SELECT oid, format_type(oid, NULL) FROM pg_type WHERE oid = ANY(%s)",
                    (list(oids),))
        result = dict(cur.fetchall())
    conn.rollback()
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--folder", default="dashboard_queries", help="Folder containing final SQL queries")
    p.add_argument("--demographic", choices=ALLOWED_DEMOGRAPHICS, default="country")
    p.add_argument("--min-users", type=int, default=20)
    p.add_argument("--min-resp", type=int, default=20)
    p.add_argument("--top-n", type=int, default=5)
    p.add_argument("--country", action="append", help="Optional country filter (repeatable)")
    p.add_argument("--role", action="append", help="Optional role filter (repeatable)")
    p.add_argument("--age-group", action="append", help="Optional age-group filter (repeatable)")
    p.add_argument("--min-years", type=int)
    p.add_argument("--max-years", type=int)
    p.add_argument("--sample", type=int, default=4)
    args = p.parse_args()
    folder = BASE / args.folder
    if not folder.is_dir():
        raise SystemExit(f"Missing SQL folder: {folder}")
    sql_files = sorted(x for x in folder.glob("*.sql")
                       if x.name[:2].isdigit() and not x.name.startswith("15_")
                       and "helper" not in x.name.lower())
    if not sql_files:
        raise SystemExit(f"No analytical .sql files in {folder}")
    report_dir = BASE / "reports" / "query_tests"
    report_dir.mkdir(parents=True, exist_ok=True)
    params = dict(PARAMS, countries=args.country, roles=args.role,
                  age_groups=args.age_group, min_years=args.min_years,
                  max_years=args.max_years, min_users=args.min_users,
                  min_resp=args.min_resp, top_n=args.top_n)
    test_log = []
    with connection() as conn:
        cols = get_available_types(conn)
        with (report_dir / "schema_column_types.csv").open("w", newline="", encoding="utf-8-sig") as f:
            w = csv.writer(f)
            w.writerow(["schema", "table", "column", "postgres_type", "nullable"])
            w.writerows(cols)
        view_ok, function_ok = prerequisites(conn)
        if not view_ok or not function_ok:
            print(f"MISSING prereqs: v_ai_trust={view_ok}, eligible_respondents={function_ok}")
            print("Run: python run_sql_file.py sql/setup_dashboard_helpers.sql dashboard_setup")
            print("(Copy setup_dashboard_helpers.sql into projectB/sql/ first.)")
            return 2
        with conn.cursor() as cur:
            cur.execute("SELECT respondent_id FROM survey.respondents ORDER BY respondent_id LIMIT 1")
            respondent = cur.fetchone()
        conn.rollback()
        if respondent is None:
            raise SystemExit("survey.respondents is empty")
        params["respondent_id"] = respondent[0]

        for path in sql_files:
            print(f"\n--- {path.name} ---")
            state, note, names_and_types = "PASS", "", ""
            row_count_sample = 0
            try:
                query = path.read_text(encoding="utf-8-sig").strip()
                # Each file MUST contain a single read-only SELECT or WITH SELECT.
                body = re.sub(r"\A(?:\s|--[^\n]*\n|/\*[\s\S]*?\*/)*", "", query).lstrip()
                if not re.match(r"^(SELECT|WITH)\b", body, flags=re.I):
                    raise ValueError("Expected SELECT or WITH query; maintenance SQL must run separately")
                if re.search(r";\s*\S", body):
                    raise ValueError("Multiple SQL statements not supported by safe tester")
                # Strip optional trailing semicolon, then fetch a small sample only.
                query = query.rstrip().rstrip(";").rstrip()
                with conn.cursor() as cur:
                    cur.execute("SET TRANSACTION READ ONLY")
                    cur.execute("SET LOCAL statement_timeout = '45000ms'")
                    if "{col}" in query:
                        templated = sql.SQL(query).format(col=sql.Identifier(args.demographic))
                        cur.execute(templated, params)
                    else:
                        cur.execute(query, params)
                    if cur.description is None:
                        raise ValueError("Query did not return a result set")
                    headers = [d.name for d in cur.description]
                    types = [d.type_code for d in cur.description]
                    rows = cur.fetchmany(args.sample)
                    row_count_sample = len(rows)
                    expected = EXPECTED_COLUMNS.get(path.stem)
                    if expected and not expected.issubset(set(headers)):
                        raise ValueError(f"Missing expected output columns: {sorted(expected-set(headers))}")
                    type_mapping = {oid: "?" for oid in types}
                    # PostgreSQL type OIDs are stable here; resolve outside the transaction below.
                    names_and_types = [(name, typ) for name, typ in zip(headers, types)]
                    print("Columns:", ", ".join(headers))
                    for row in rows:
                        print("  ", tuple(str(v)[:100] if v is not None else None for v in row))
                    if not rows:
                        state = "EMPTY"
                        note = "Executed but returned no records; inspect question codes/filters"
            except Exception as exc:
                state, note = "FAIL", str(exc).splitlines()[0][:300]
                print("ERROR:", note)
            finally:
                conn.rollback()  # Read-only queries NEVER persist changes.
            if names_and_types:
                typenames = oid_type(conn, {oid for _, oid in names_and_types})
                names_and_types = ", ".join(f"{name}: {typenames.get(oid, oid)}" for name, oid in names_and_types)
                print("Types:", names_and_types)
            print("Status:", state, note)
            test_log.append((path.name, state, row_count_sample, names_and_types, note))
    with (report_dir / "query_test_results.csv").open("w", newline="", encoding="utf-8-sig") as f:
        wr = csv.writer(f)
        wr.writerow(["sql_file", "status", "sample_rows", "returned_column_types", "notes"])
        wr.writerows(test_log)
    nfail = sum(s == "FAIL" for _, s, *_ in test_log)
    nempty = sum(s == "EMPTY" for _, s, *_ in test_log)
    print(f"\nFinished {len(test_log)} queries: {nfail} failed, {nempty} empty. ")
    print("Saved reports/query_tests/query_test_results.csv and schema_column_types.csv")
    print("NOTE: Q15 deletion test intentionally excluded. It must always ROLLBACK.")
    return 1 if nfail else 0


if __name__ == "__main__":
    raise SystemExit(main())
