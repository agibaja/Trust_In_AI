from run_sql_file import run_sql_file

if __name__ == '__main__':
    run_sql_file(
        'sql/clean_data_profiling.sql',
        'clean_profiling'
    )