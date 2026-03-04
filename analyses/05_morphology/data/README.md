# data — Morphology Source Data

Source trait and taxonomy data files used by the ETL pipeline (`../etl_gliridae.py`). These files are included in the repository for full reproducibility.

## Files

| File | Source | Description |
|---|---|---|
| `MDD_v2.3_6836species_Gliridae.csv` | Mammal Diversity Database v2.3 | Accepted species taxonomy and names for Gliridae |
| `Species_Syn_v2.3_Gliridae.csv` | MDD v2.3 | Synonymy and nomenclatural history for Gliridae species |
| `hmw-volume-6-gliridae.csv` | Handbook of the Mammals of the World, Vol. 6 | Morphometric and ecological traits (Lynx Edicions) |
| `africanmammalia-measurements.csv` | African Mammalia literature | Additional body measurements |
| `africanmammalia-measurements-documentation.docx` | – | Column definitions and source documentation for the above |
| `samples-study.csv` | This study | Specimen-level metadata for all samples used in genomic analyses |

## Data Sources

**MDD** — Mammal Diversity Database. Freely available at https://www.mammaldiversity.org/. Cite as: Mammal Diversity Database (2024), v2.3.

**HMW** — Wilson, D.E. & Mittermeier, R.A. (2016). Handbook of the Mammals of the World, Vol. 6: Lagomorphs and Rodents I. Lynx Edicions, Barcelona. Redistribution subject to publisher's terms.

## Usage

Pass these files as inputs to the ETL pipeline. See `../README.md` for the full command.
