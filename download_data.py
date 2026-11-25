"""Download Project B's exact Kaggle dataset and build archive.zip for the ETL.

Source: https://www.kaggle.com/datasets/kaitoland/stack-overflow-2026-developer-trust-in-ai

Install: python -m pip install kagglehub
Usage:
  python download_data.py                 # validate local archive, or download if absent
  python download_data.py --force         # fetch Kaggle and replace archive only if valid
  python download_data.py --check-rows    # also count rows for all six CSVs

The ETL expects a ZIP with six CSVs at its root, not CSVs extracted into a folder.
This script never runs SQL, changes the database, or performs survey analysis.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
from pathlib import Path
import tempfile
import zipfile

DATASET = "kaitoland/stack-overflow-2026-developer-trust-in-ai"
BASE = Path(__file__).resolve().parent
DEST = BASE / "archive.zip"
REQUIRED_COUNTS = {
    "respondents.csv": 30903,
    "ai_trust_ml.csv": 14230,
    "questions.csv": 88,
    "answer_codes.csv": 135,
    "multi_select_answers.csv": 2728527,
    "data_dictionary.csv": 316,
}
# Hashes of the individual CSVs in the currently validated Project B archive.
# Hashing members, rather than the ZIP itself, permits different ZIP packaging.
EXPECTED_CSV_HASHES = {
    "respondents.csv": "5b72883f254cf3f0e462bc45cec4e6c5ec96f10ca183152aa406e606c562e008",
    "ai_trust_ml.csv": "2d4372426766b4c37ad3a27d13eadc08c83a619223dbf3b37dc88091de7491a3",
    "questions.csv": "de61bb0ffcf623c099319b02f0dd52666eba5f9d2f0ed096c4f3955e5c9fed59",
    "answer_codes.csv": "4aee392e69ff12771c4ad45e1e41c4273e367c0a50b2ca5fc2515e451b954229",
    "multi_select_answers.csv": "0152f8ec45dfd96494a1320d6d4472a3ff1fc6edbd827588dea868705e9889c8",
    "data_dictionary.csv": "a2f3e97a1712599a417b956c4c896a49862440ce42fd87e938175690ba97581e",
}


def validate(archive_path: Path, check_rows: bool = False, allow_changed: bool = False) -> None:
    with zipfile.ZipFile(archive_path) as zf:
        member_names = set(zf.namelist())
        missing = REQUIRED_COUNTS.keys() - member_names
        if missing:
            raise ValueError(f"Missing expected CSV files: {sorted(missing)}")
        for name in REQUIRED_COUNTS:
            digest = hashlib.sha256()
            with zf.open(name) as f:
                for chunk in iter(lambda: f.read(1024 * 1024), b""):
                    digest.update(chunk)
            actual = digest.hexdigest()
            expected = EXPECTED_CSV_HASHES[name]
            if actual != expected:
                if not allow_changed:
                    raise ValueError(
                        f"Dataset version differs for {name}.\n"
                        f"Expected: {expected}\nGot:      {actual}\n"
                        "Existing ETL was validated on the previous version. "
                        "Review source changes before using --allow-changed."
                    )
                print(f"WARNING: Source changed since profiling: {name}")
            if check_rows:
                with zf.open(name) as binary:
                    with io.TextIOWrapper(binary, encoding="utf-8-sig", newline="") as text:
                        count = sum(1 for _ in csv.reader(text)) - 1
                if count != REQUIRED_COUNTS[name]:
                    raise ValueError(f"Unexpected row count for {name}: {count:,}; expected {REQUIRED_COUNTS[name]:,}")
                print(f"  {name}: {count:,} rows")
    print(f"VALID: {archive_path} — all six CSVs present and validated")


def download_and_package() -> Path:
    try:
        import kagglehub
    except ImportError as exc:
        raise SystemExit("Install Kaggle Hub first: python -m pip install kagglehub") from exc

    print(f"Downloading Kaggle dataset: {DATASET}")
    source_dir = Path(kagglehub.dataset_download(DATASET))
    print(f"Kaggle download folder: {source_dir}")
    # Some versions of the dataset may have files nested in directories.
    found = {}
    for path in source_dir.rglob("*"):
        if path.is_file() and path.name in REQUIRED_COUNTS:
            if path.name in found:
                raise ValueError(f"Ambiguous duplicate filename in Kaggle download: {path.name}")
            found[path.name] = path
    missing = REQUIRED_COUNTS.keys() - found.keys()
    if missing:
        raise ValueError(
            f"Kaggle files do not match your ETL: {sorted(missing)} missing. "
            f"Available files: {sorted(p.name for p in source_dir.rglob('*') if p.is_file())}"
        )
    extra = {p.name: p for p in source_dir.rglob("*") if p.is_file() and p.name in {"sources.md", "EXCLUSIONS.md"}}
    tmp = tempfile.NamedTemporaryFile(prefix="projectb-kaggle-", suffix=".zip", dir=BASE, delete=False)
    tmp.close()
    candidate = Path(tmp.name)
    try:
        with zipfile.ZipFile(candidate, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
            for name in REQUIRED_COUNTS:
                zf.write(found[name], arcname=name)
            for name, path in extra.items():
                zf.write(path, arcname=name)
        return candidate
    except BaseException:
        candidate.unlink(missing_ok=True)
        raise


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--force", action="store_true", help="Download again and replace local archive after validating")
    p.add_argument("--check-rows", action="store_true", help="Check the row count of each CSV")
    p.add_argument("--allow-changed", action="store_true", help="Allow new Kaggle file hashes (requires checking schema and profiling again)")
    args = p.parse_args()
    if DEST.exists() and not args.force:
        validate(DEST, check_rows=args.check_rows, allow_changed=args.allow_changed)
        print("Using existing archive.zip; pass --force to test actual Kaggle download.")
        return
    candidate = download_and_package()
    try:
        validate(candidate, check_rows=args.check_rows, allow_changed=args.allow_changed)
        candidate.replace(DEST)
        print(f"READY: {DEST}")
    finally:
        candidate.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
