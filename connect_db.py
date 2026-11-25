
import psycopg2
from psycopg2 import sql

# Read PostgreSQL password
with open("password.txt") as f:
    password = f.read().strip()

#Connect to the default PostgreSQL database
conn = psycopg2.connect(
    host="localhost",
    port=5432,
    dbname="postgres",
    user="postgres",
    password=password,
)

conn.autocommit = True

#Create our project database
with conn.cursor() as cur:
    cur.execute(
        "SELECT 1 FROM pg_database WHERE datname = %s",
        ("ai_survey",)
    )

    if cur.fetchone() is None:
        cur.execute(
            sql.SQL("CREATE DATABASE {}").format(
                sql.Identifier("ai_survey")
            )
        )
        print("Database 'ai_survey' created successfully!")
    else:
        print("Database 'ai_survey' already exists.")

conn.close()

#Connect to our project database
conn = psycopg2.connect(
    host="localhost",
    port=5432,
    dbname="ai_survey",
    user="postgres",
    password=password,
)

#Check the connection
with conn:
    with conn.cursor() as cur:
        cur.execute("SELECT current_database()")
        database_name = cur.fetchone()[0]
        print(f"Connected to: {database_name}")

conn.close()
