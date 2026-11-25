"""Recreate EMPTY schemas; runs DDL separately from ETL, as required.
WARNING: destroys existing raw and survey schema contents.
"""
from pathlib import Path
import psycopg2

BASE = Path(__file__).resolve().parent
password = (BASE / 'password.txt').read_text(encoding='utf-8').strip()
conn = psycopg2.connect(host='localhost',port=5432,dbname='ai_survey',user='postgres',password=password)
try:
    with conn:
        with conn.cursor() as cur:
            cur.execute((BASE/'sql'/'schema.sql').read_text(encoding='utf-8'))
    print('Empty schemas created with constraints. Next: python load_raw2db.py')
finally:
    conn.close()
