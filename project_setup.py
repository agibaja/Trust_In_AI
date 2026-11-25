"""Rebuild and validate Project B from the project root.

Usage (after activating your conda environment):
    python project_setup.py
    python project_setup.py --yes --launch
    python project_setup.py --skip-install --skip-audit

WARNING: build_schema.py drops and recreates the raw/survey schemas.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent


def run_step(label: str, *args: str) -> None:
    print(f"\n{'=' * 68}\n{label}\n{'=' * 68}", flush=True)
    subprocess.run([sys.executable, *args], cwd=PROJECT_DIR, check=True)


def require_file(relative_path: str) -> None:
    if not (PROJECT_DIR / relative_path).is_file():
        raise FileNotFoundError(f"Required project file missing: {relative_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Initialize Project B PostgreSQL database and dashboard")
    parser.add_argument("--yes", action="store_true", help="Confirm destructive database rebuild without prompting")
    parser.add_argument("--launch", action="store_true", help="Launch Streamlit after successful initialization")
    parser.add_argument("--skip-install", action="store_true", help="Skip pip dependency installation")
    parser.add_argument("--skip-audit", action="store_true", help="Skip optional analytical correctness audit")
    args = parser.parse_args()

    required = [
        "download_data.py", "connect_db.py", "build_schema.py", "load_raw2db.py",
        "verify_db.py", "run_profiling.py", "run_clean_profiling.py",
        "run_sql_file.py", "sql/setup_dashboard_helpers.sql",
        "test_dashboard_queries.py", "dashboard.py", "password.txt",
    ]
    if not args.skip_install:
        required.append("requirements.txt")
    if not args.skip_audit:
        required.append("sql/analytical_correctness_audit.sql")
    for filename in required:
        require_file(filename)

    print(f"Project directory: {PROJECT_DIR}")
    print(f"Python executable: {sys.executable}")
    print("WARNING: The schema-build step DROPS and RECREATES raw and survey schemas.")
    if not args.yes:
        response = input("Type REBUILD to proceed, or anything else to cancel: ").strip()
        if response != "REBUILD":
            print("Cancelled. No commands have been run.")
            return 1

    steps = [
        ("Download or validate dataset", ["download_data.py"]),
        ("Create/check PostgreSQL database", ["connect_db.py"]),
        ("Recreate database schemas (DESTRUCTIVE)", ["build_schema.py"]),
        ("Load, transform and clean data", ["load_raw2db.py"]),
        ("Verify database", ["verify_db.py"]),
        ("Profile source data", ["run_profiling.py"]),
        ("Profile cleaned data", ["run_clean_profiling.py"]),
        ("Create dashboard view and filtering function", ["run_sql_file.py", "sql/setup_dashboard_helpers.sql", "dashboard_setup"]),
        ("Test dashboard SQL queries", ["test_dashboard_queries.py"]),
    ]
    try:
        if not args.skip_install:
            run_step("Install project dependencies","-m", "pip", "install", "-r", "requirements.txt")
        for label, command in steps:
            run_step(label, *command)
        if not args.skip_audit:
            run_step("Run analytical correctness audit", "run_sql_file.py", "sql/analytical_correctness_audit.sql", "analytical_audit")
        print("\nInitialization commands completed successfully.", flush=True)
        print("Check the SQL test and audit outputs for FAIL/REVIEW statuses; process completion alone does not guarantee analytical correctness.")
        if args.launch:
            run_step("Launch Streamlit dashboard", "-m", "streamlit", "run", "dashboard.py")
        else:
            print("Start dashboard using: python -m streamlit run dashboard.py")
        return 0
    except (subprocess.CalledProcessError, OSError) as exc:
        print(f"\nSETUP STOPPED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
