#!/usr/bin/env python3
"""Convert TCDB CSV rows into JSON for Sector's type/creator lookup."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path


def load_entries(csv_path: Path) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    duplicate_count = 0

    with csv_path.open("r", encoding="utf-8-sig", newline="") as file:
        reader = csv.reader(file)
        header = next(reader, None)
        if not header or len(header) < 3:
            raise ValueError("CSV must contain at least three columns: File Name, Type, Creator")

        for line_number, row in enumerate(reader, start=2):
            if len(row) < 3:
                print(f"Skipping line {line_number}: fewer than 3 columns", file=sys.stderr)
                continue

            file_name = row[0].strip()
            type_code = row[1].strip()
            creator_code = row[2].strip()

            if not file_name or not type_code or not creator_code:
                continue

            key = (type_code, creator_code)
            if key in seen:
                duplicate_count += 1
                continue

            seen.add(key)
            entries.append({
                "fileName": file_name,
                "type": type_code,
                "creator": creator_code,
            })

    if duplicate_count:
        print(f"Skipped {duplicate_count} duplicate type/creator keys; first value kept.", file=sys.stderr)

    return entries


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert the first three TCDB CSV columns into a JSON lookup resource."
    )
    parser.add_argument("csv_path", type=Path, help="Path to TCDB CSV input")
    parser.add_argument("-o", "--output", type=Path, required=True, help="JSON output file")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    try:
        entries = load_entries(args.csv_path)
        args.output.write_text(
            json.dumps(entries, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
    except Exception as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
