"""
preprocess_ev_data.py
---------------------
Preprocesses the raw Electric Vehicle Population Data CSV for loading
into SQL Server via BULK INSERT.

Input:  Electric_Vehicle_Population_Data.csv  (downloaded from Kaggle)
Output: EV_Data.csv  (cleaned, ready for BULK INSERT)

Changes applied:
  1. Drops Vehicle Location column (WKT POINT strings with embedded spaces
     cause SQL Server BULK INSERT column misalignment)
  2. Drops 2020 Census Tract column (BIGINT overflow on certain rows)
  3. Renames all columns to remove spaces and special characters
  4. Simplifies Electric Utility to the first provider only
     (raw values are pipe-delimited multi-provider strings)
  5. Converts Legislative District float nulls to empty strings
  6. Fills remaining nulls in string columns with empty strings

Usage:
  python preprocess_ev_data.py

  By default reads from the current directory and writes EV_Data.csv
  to the current directory. Edit INPUT_PATH and OUTPUT_PATH below
  to change locations.
"""

import pandas as pd

# ── Paths ──────────────────────────────────────────────────────────────────────
INPUT_PATH  = "Electric_Vehicle_Population_Data.csv"
OUTPUT_PATH = "EV_Data.csv"


def clean_utility(val):
    """Extract the first utility provider from a pipe-delimited string."""
    if not val or pd.isna(val):
        return ""
    # Split on pipe, take first segment
    first = str(val).split("|")[0].strip()
    # If a comma remains, take everything before it
    if "," in first:
        first = first.split(",")[0].strip()
    return first


def preprocess(input_path, output_path):
    print(f"Reading: {input_path}")
    df = pd.read_csv(input_path)
    print(f"  Raw shape: {df.shape}")

    # 1. Drop problematic columns
    drop_cols = ["Vehicle Location", "2020 Census Tract"]
    df = df.drop(columns=[c for c in drop_cols if c in df.columns])
    print(f"  Dropped columns: {drop_cols}")

    # 2. Rename columns to remove spaces and special characters
    df.columns = [
        "VIN",
        "County",
        "City",
        "State",
        "PostalCode",
        "ModelYear",
        "Make",
        "Model",
        "ElectricVehicleType",
        "CAFVEligibility",
        "ElectricRange",
        "BaseMSRP",
        "LegislativeDistrict",
        "DOLVehicleID",
        "ElectricUtility",
    ]
    print(f"  Columns renamed: {list(df.columns)}")

    # 3. Simplify Electric Utility to first provider only
    df["ElectricUtility"] = df["ElectricUtility"].apply(clean_utility)

    # 4. Convert Legislative District float nulls to empty strings
    df["LegislativeDistrict"] = df["LegislativeDistrict"].apply(
        lambda x: "" if pd.isna(x) else str(int(x))
    )

    # 5. Fill remaining string column nulls with empty strings
    for col in ["Model", "ElectricUtility", "County", "City", "State", "Make"]:
        df[col] = df[col].fillna("")

    # 6. Verify no commas remain in any text column that would break BULK INSERT
    text_cols = [
        "VIN", "County", "City", "State", "Make", "Model",
        "ElectricVehicleType", "CAFVEligibility",
        "ElectricUtility", "LegislativeDistrict",
    ]
    issues = []
    for col in text_cols:
        n = df[col].astype(str).str.contains(",").sum()
        if n > 0:
            issues.append(f"  WARNING: {col} still has {n} rows with commas")
    if issues:
        for w in issues:
            print(w)
    else:
        print("  Verification passed: no commas in any text column")

    # 7. Write output — no index, no quoting of numeric fields
    df.to_csv(output_path, index=False, quoting=0)
    print(f"\nOutput written: {output_path}")
    print(f"  Final shape:   {df.shape}")
    print(f"  Columns:       {list(df.columns)}")


if __name__ == "__main__":
    preprocess(INPUT_PATH, OUTPUT_PATH)
