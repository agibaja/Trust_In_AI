"""Execute every statement in a SQL file and export EVERY result set.

Requires: pip install psycopg2-binary sqlparse
All aggregations/calculations are performed by PostgreSQL, not Python.
"""
import argparse
import csv
import re
from datetime import datetime
from pathlib import Path

import psycopg2
import sqlparse

BASE_DIR = Path(__file__).resolve().parent


def run_sql_file(relative_sql_path: str, report_name: str) -> None:
    sql_path = BASE_DIR / relative_sql_path
    password_path = BASE_DIR / 'password.txt'
    if not sql_path.is_file():
        raise FileNotFoundError(f'SQL file not found: {sql_path}')
    if not password_path.is_file():
        raise FileNotFoundError(f'Password file not found: {password_path}')

    statements = [s.strip() for s in sqlparse.split(sql_path.read_text(encoding='utf-8-sig')) if s.strip()]
    output_dir = BASE_DIR / 'reports' / report_name
    output_dir.mkdir(parents=True, exist_ok=True)
    logfile = output_dir / 'results.txt'
    conn = psycopg2.connect(
        host='localhost', port=5432, dbname='ai_survey', user='postgres',
        password=password_path.read_text(encoding='utf-8').strip(),
    )
    total_results = 0
    try:
        # One connection and one transaction: TEMP TABLES survive between statements.
        with conn:
            with conn.cursor() as cur, logfile.open('w', encoding='utf-8') as log:
                def show(message=''):
                    print(message)
                    log.write(message + '\n')

                show(f'SQL source: {sql_path}')
                show(f'Started: {datetime.now().isoformat(timespec="seconds")}')
                for index, statement in enumerate(statements, 1):
                    # sqlparse handles semicolons within DO $$ ... $$ and quoted strings.
                    meaningful = sqlparse.format(statement, strip_comments=True).strip()
                    if not meaningful:
                        continue
                    statement_start = re.sub(r'\s+', ' ', meaningful)[:180]
                    show(f'\n[{index:02d}/{len(statements):02d}] {statement_start}')
                    try:
                        cur.execute(statement)
                    except psycopg2.Error as exc:
                        show(f'FAILED at statement #{index}: {exc.pgerror or str(exc)}')
                        show('Transaction will be rolled back; fix the SQL and rerun.')
                        raise

                    if cur.description is None:
                        show(f'Completed ({cur.statusmessage})')
                        continue

                    total_results += 1
                    out_csv = output_dir / f'result_{total_results:02d}.csv'
                    headers = [col.name for col in cur.description]
                    row_total = 0
                    with out_csv.open('w', newline='', encoding='utf-8-sig') as f:
                        writer = csv.writer(f)
                        writer.writerow(headers)
                        show(' | '.join(headers))
                        while True:
                            rows = cur.fetchmany(1000)
                            if not rows:
                                break
                            for row in rows:
                                # Python only formats the SQL results for output.
                                writer.writerow(row)
                                show(' | '.join('NULL' if value is None else str(value) for value in row))
                                row_total += 1
                    show(f'Result: {row_total} rows -> {out_csv.relative_to(BASE_DIR)}')
                show(f'\nSUCCESS: {total_results} result sets saved in {output_dir.relative_to(BASE_DIR)}')
    finally:
        conn.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('sql_path', help='Path relative to project folder, e.g. sql/verify.sql')
    parser.add_argument('report_name', help='Subfolder of reports, e.g. verification')
    args = parser.parse_args()
    run_sql_file(args.sql_path, args.report_name)
