"""Load six source CSVs with PostgreSQL COPY, then populate seven normalized tables.

Prerequisite: create schema with sql/schema.sql (run separately).
The whole ETL is one transaction, so an error rolls back all loaded data.
WARNING: schema.sql DROPS raw and survey schemas; do not run on a production database.
"""
import csv
import io
import zipfile
import tempfile
from pathlib import Path

import psycopg2
from psycopg2 import sql
from mapping import PERSON_COLUMNS, WORK_COLUMNS, EXCLUDED_PREFIXES, MATRIX_PREFIXES

BASE = Path(__file__).resolve().parent
ZIP_PATH = BASE / "archive.zip"
CSV_TABLES = (
    "respondents", "ai_trust_ml", "questions",
    "answer_codes", "multi_select_answers", "data_dictionary"
)

def get_connection():
    password = (BASE / "password.txt").read_text(encoding="utf-8").strip()
    return psycopg2.connect(host="localhost", port=5432,
                            dbname="ai_survey", user="postgres", password=password)


def copy_file(cur, archive, name):
    with archive.open(f"{name}.csv") as binary:
        with io.TextIOWrapper(binary, encoding="utf-8-sig", newline="") as source:
            query = sql.SQL("COPY {} FROM STDIN WITH (FORMAT csv, HEADER true)").format(
                sql.Identifier("raw", name)
            )
            cur.copy_expert(query.as_string(cur.connection), source)


def copy_scalar_answers(cur, archive):
    """Unpivot respondent answer columns without pandas and without in-memory datasets.

    The transformation is a format change, not statistical data analysis.
    Blank/unanswered cells generate no answer records. This is documented.
    """
    excluded = set(PERSON_COLUMNS) | set(WORK_COLUMNS)
    # Spooled stream switches to disk beyond 8 MB, avoiding millions of RAM rows.
    with tempfile.SpooledTemporaryFile(mode="w+", max_size=8 * 1024 * 1024,
                                       encoding="utf-8", newline="") as out:
        writer = csv.writer(out)
        with archive.open("respondents.csv") as binary:
            with io.TextIOWrapper(binary, encoding="utf-8-sig", newline="") as f:
                reader = csv.DictReader(f)
                cols = [c for c in reader.fieldnames
                        if c not in excluded
                        and not c.endswith("_code")
                        and not c.startswith(EXCLUDED_PREFIXES)]
                mapping = {}
                for c in cols:
                    prefix = next((p for p in MATRIX_PREFIXES if c.startswith(p)), None)
                    mapping[c] = (prefix.rstrip("_"), c[len(prefix):]) if prefix else (c, "")
                for row in reader:
                    respondent_id = row["respondent_id"]
                    for column in cols:
                        value = row[column]
                        if value is None or value == "":
                            continue
                        question_code, item_code = mapping[column]
                        writer.writerow([respondent_id, question_code, item_code, value])
        out.seek(0)
        cur.copy_expert(
            "COPY raw.scalar_answers(respondent_id,question_code,item_code,raw_value) "
            "FROM STDIN WITH (FORMAT csv, NULL '')", out
        )


def main():
    if not ZIP_PATH.exists():
        raise FileNotFoundError(f"Place archive.zip next to this script: {ZIP_PATH}")
    conn = get_connection()
    try:
        with conn:
            with conn.cursor() as cur:
                # Avoid silently appending to an already-populated schema.
                cur.execute("SELECT COUNT(*) FROM survey.respondents")
                if cur.fetchone()[0]:
                    raise RuntimeError("Survey tables contain data. Rebuild schema.sql first.")
                with zipfile.ZipFile(ZIP_PATH) as archive:
                    for name in CSV_TABLES:
                        print("COPY:", name, flush=True)
                        copy_file(cur, archive, name)
                    print("COPY: scalar_answers (transforming wide respondents.csv)", flush=True)
                    copy_scalar_answers(cur, archive)
                print("Populating final tables with SQL...", flush=True)
                transform = (BASE / "sql" / "transform.sql").read_text(encoding="utf-8")
                cur.execute(transform)

                # Apply the documented >60%-missing respondent filter INSIDE
                # this same transaction. An error rolls back both load and cleaning.
                cleaning = (BASE / "sql" / "filter_respondents.sql").read_text(encoding="utf-8")
                cur.execute(cleaning)
                cur.execute("SELECT COUNT(*) FROM excluded_respondents")
                removed = cur.fetchone()[0]
                cur.execute("SELECT COUNT(*) FROM survey.respondents")
                retained = cur.fetchone()[0]
                print(f"Cleaning (>60% missing): removed {removed:,}; retained {retained:,}")

                for table in ("respondents", "work_info", "questions", "question_items",
                              "technologies", "answer_options", "answers"):
                    cur.execute(
                        sql.SQL("SELECT COUNT(*) FROM {}").format(sql.Identifier("survey", table))
                    )
                    print(f"survey.{table}: {cur.fetchone()[0]:,}")
        print("SUCCESS: transaction committed. Verify results in pgAdmin.")
    except Exception as e:
        conn.rollback()

        print("\n" + "=" * 60)
        print("ETL FAILED")
        print("=" * 60)

        print("Error type:", type(e).__name__)
        print("Error message:", str(e))

        if isinstance(e, psycopg2.Error):
            print("PostgreSQL error code:", e.pgcode)
            print("Details:", e.diag.message_detail)
            print("Context:", e.diag.context)
            print("Position:", e.diag.statement_position)

        print("\nROLLBACK completed.")
        print("No partial data was saved.")

        raise
    finally:
        conn.close()

if __name__ == "__main__":
    main()
