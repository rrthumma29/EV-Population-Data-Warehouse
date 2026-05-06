# Electric Vehicle Population Data Warehouse
### MGMT 6570 — Advanced Data Resource Management
**Rensselaer Polytechnic Institute | May 2026**

---

## Overview

This project implements a full star schema data warehouse in SQL Server for the Electric Vehicle Population Dataset, sourced from Washington State Department of Licensing registration records. The warehouse supports multi-dimensional analysis of EV adoption patterns across vehicle manufacturers, geographic locations, electric utility providers, CAFV eligibility categories, and model years spanning 2000–2023.

**Research Question:** What vehicle, location, and utility characteristics are associated with EV adoption and electric range across registered vehicles in the dataset?

---

## Dataset

| Attribute | Value |
|---|---|
| Source | [Kaggle — Electric Vehicle Population Data](https://www.kaggle.com/datasets/ratikkakkar/electric-vehicle-population-data) |
| Raw Rows | 112,634 |
| Clean Rows | 112,609 |
| Time Period | 2000–2023 |
| Primary Geography | Washington State (DOL records) |

### Preprocessing
Before loading into SQL Server, the following preprocessing was applied in Python:
- Removed `Vehicle Location` column (WKT POINT strings with embedded spaces caused BULK INSERT column misalignment)
- Removed `2020 Census Tract` column (BIGINT overflow on certain rows)
- Simplified column names (removed spaces and special characters)
- Extracted primary provider from pipe-delimited `Electric Utility` values
- Converted `Legislative District` float nulls to empty strings

The preprocessed file is saved as `EV_Data.csv` and must be placed at `C:\Data\Final_Project_EV\EV_Data.csv` before running the SQL.

---

## Star Schema

```
                    dimVehicle
                        |
        dimCAFV — factEVRegistration — dimEVType
                        |
        dimDate    dimLocation    dimUtility
```

### Tables

| Table | Type | Rows | Description |
|---|---|---|---|
| `EVStaging` | Staging | 112,634 | Raw CSV load target |
| `EVClean` | Clean | 112,609 | Typed, trimmed, date-keyed |
| `dimVehicle` | Dimension | 113 | Make + Model combinations |
| `dimLocation` | Dimension | ~4,800 | City + County + State + PostalCode |
| `dimEVType` | Dimension | 2 | BEV / PHEV — manually seeded |
| `dimCAFV` | Dimension | 3 | CAFV eligibility — manually seeded |
| `dimUtility` | Dimension | ~120 | Electric utility providers |
| `dimDate` | Dimension | 24 | One row per model year 2000–2023 |
| `factEVRegistration` | Fact | 112,609 | One row per registered vehicle |

### Fact Table Measures

| Measure | Type | Description |
|---|---|---|
| `ElectricRange` | INT | All-electric range in miles |
| `BaseMSRP` | INT | Manufacturer suggested retail price (0 = not collected) |

---

## Key Design Decisions

- **All staging columns are VARCHAR** — avoids BULK INSERT type conversion failures on blank/null numeric fields; types are cast in the EVClean INSERT step
- **DateKey = ModelYear × 10000 + 101** — stores model year as Jan 1 integer (YYYYMMDD) for consistency with standard DW date key conventions
- **dimEVType and dimCAFV are manually seeded** — low-cardinality dimensions with no IDENTITY; keys are supplied explicitly in VALUES
- **EVTypeKey and CAFVKey resolved via CASE** — fact load uses CASE statements rather than joins for manually-seeded dimensions
- **FK columns allow NULLs** — vehicles with no utility provider or unresolvable keys are retained in the fact table with NULL foreign keys
- **Electric Utility simplified** — pipe-delimited multi-provider strings reduced to first provider only during EVClean INSERT

---

## How to Run

### Prerequisites
- SQL Server 2019 or later
- SQL Server Management Studio (SSMS)
- `EV_Data.csv` placed at `C:\Data\Final_Project_EV\EV_Data.csv`

### Steps

1. **Create the database**
```sql
CREATE DATABASE EVDW;
```

2. **Open** `EV_Dataset_DW_Final_Project.sql` in SSMS

3. **Run sections in order:**
   - Staging table (DROP + CREATE + BULK INSERT)
   - Clean table (DROP + CREATE + INSERT)
   - Dimension tables (DROP all → CREATE + INSERT each)
   - Fact table (CREATE + INSERT)
   - Verification queries
   - Analysis queries

4. **Export analysis query results** as CSV for visualization in R

### Expected Row Counts

| Table | Expected Count |
|---|---|
| EVStaging | 112,634 |
| EVClean | ~112,609 |
| dimVehicle | 113 |
| dimEVType | 2 |
| dimCAFV | 3 |
| dimDate | 24 |
| factEVRegistration | ~112,609 |

---

## Analysis Queries

The SQL file includes 6 analysis queries at the bottom, each designed to export as a CSV for R visualization:

| Query | Output File | Description |
|---|---|---|
| Query 1 | `registrations_by_make.csv` | Registration count and avg range by manufacturer |
| Query 2 | `bev_phev_by_year.csv` | BEV vs PHEV adoption trend by model year |
| Query 3 | `top_counties.csv` | Top 15 counties by registration count |
| Query 4 | `cafv_eligibility.csv` | CAFV eligibility breakdown by EV type |
| Query 5 | `top_utilities.csv` | Top 10 electric utilities by registration count |
| Query 6 | `adoption_by_era.csv` | EV growth across four adoption eras |

---

## Key Findings

- **Tesla dominates** with 52,078 registrations (46% of dataset) and the highest average electric range at 118 miles
- **King County, WA** leads geographic adoption with 58,985 registrations — more than 4× the next county
- **BEV registrations grew from 59 (2000–2010) to 57,798 (2020–2023)** — a ~980× increase
- **CAFV policy structurally favors BEVs** — 46,794 BEVs are eligible vs only 11,840 PHEVs
- **Puget Sound Energy** serves the largest EV fleet with 65,074 registrations in its territory

---

## Repository Structure

```
├── EV_Dataset_DW_Final_Project.sql   # Full SQL — staging, clean, dims, fact, analysis
├── EV_Data.csv                       # Preprocessed source data (not tracked if large)
├── README.md                         # This file
```

---

## Course Information

- **Course:** MGMT 6570 — Advanced Data Resource Management
- **Professor:** Jonathan McKinney
- **Institution:** Rensselaer Polytechnic Institute
- **Term:** Spring 2026
