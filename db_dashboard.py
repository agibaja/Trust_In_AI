"""PostgreSQL access for Project B. All analytical SQL is read-only."""
import os
from pathlib import Path
from decimal import Decimal
import psycopg2
from psycopg2 import sql as psql

BASE = Path(__file__).resolve().parent
QUERIES = BASE / 'dashboard_queries'
ALLOWED_DEMOGRAPHICS = {'age_group','gender','country','education','coder_type',
                        'so_account','so_years','years_coding'}

def connect():
    password = os.getenv('PGPASSWORD')
    if password is None:
        path = BASE / 'password.txt'
        if not path.exists():
            raise RuntimeError('Missing password.txt or PGPASSWORD')
        password = path.read_text(encoding='utf-8').strip()
    return psycopg2.connect(host=os.getenv('PGHOST','localhost'),
        port=int(os.getenv('PGPORT','5432')), dbname=os.getenv('PGDATABASE','ai_survey'),
        user=os.getenv('PGUSER','postgres'),password=password,connect_timeout=8)

def _rows(cur):
    cols=[d.name for d in cur.description]
    return [dict(zip(cols,(float(v) if isinstance(v,Decimal) else v for v in rec)))
            for rec in cur.fetchall()]

def run_query(filename, params=None, dimension=None):
    # Only whitelisted filenames; statements must originate in locally controlled files.
    if not filename.endswith('.sql') or '/' in filename or '\\' in filename:
        raise ValueError('Invalid SQL file')
    query_file=QUERIES/filename
    if not query_file.exists():
        raise FileNotFoundError(f'Missing {query_file}')
    body=query_file.read_text(encoding='utf-8-sig')
    if dimension is not None:
        if dimension not in ALLOWED_DEMOGRAPHICS or filename!='01_demographic.sql':
            raise ValueError('Disallowed demographic')
        body=psql.SQL(body).format(col=psql.Identifier(dimension))
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute('SET TRANSACTION READ ONLY')
            cur.execute("SET LOCAL statement_timeout = '45000ms'")
            cur.execute(body, params or {})
            return _rows(cur)

def fetch_filters():
    """SQL-only source for available dropdown values."""
    result={}
    with connect() as conn:
        with conn.cursor() as cur:
            cur.execute('SET TRANSACTION READ ONLY')
            for key,statement in {
                'countries':'SELECT DISTINCT country FROM survey.respondents WHERE country IS NOT NULL ORDER BY 1',
                'roles':'SELECT DISTINCT role FROM survey.work_info WHERE role IS NOT NULL ORDER BY 1',
                'age_groups':'SELECT DISTINCT age_group FROM survey.respondents WHERE age_group IS NOT NULL ORDER BY 1'
            }.items():
                cur.execute(statement)
                result[key]=[r[0] for r in cur.fetchall()]
            cur.execute('SELECT MIN(respondent_id) FROM survey.respondents')
            result['example_respondent']=cur.fetchone()[0]
    return result

def rollback_delete_demo(respondent_id):
    """Execute Q15 deletes temporarily, then always roll back."""
    conn=connect()
    try:
        with conn.cursor() as cur:
            cur.execute('SELECT COUNT(*) FROM survey.respondents WHERE respondent_id=%s',(respondent_id,))
            if not cur.fetchone()[0]:
                return {'found':False}
            cur.execute('DELETE FROM survey.answers WHERE respondent_id=%s',(respondent_id,))
            answers=cur.rowcount
            cur.execute('DELETE FROM survey.work_info WHERE respondent_id=%s',(respondent_id,))
            work=cur.rowcount
            cur.execute('DELETE FROM survey.respondents WHERE respondent_id=%s',(respondent_id,))
            respondent=cur.rowcount
            cur.execute('SELECT COUNT(*) FROM survey.respondents WHERE respondent_id=%s',(respondent_id,))
            after_delete=cur.fetchone()[0]
        conn.rollback()
        with conn.cursor() as cur:
            cur.execute('SELECT COUNT(*) FROM survey.respondents WHERE respondent_id=%s',(respondent_id,))
            restored=cur.fetchone()[0]
        return {'found':True,'deleted_answers_temporarily':answers,'deleted_work_rows_temporarily':work,
                'deleted_respondents_temporarily':respondent,'exists_inside_transaction':bool(after_delete),
                'exists_after_rollback':bool(restored)}
    finally:
        conn.rollback()
        conn.close()
