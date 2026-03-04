#!/usr/bin/env python3
"""
Gliridae (Dormice) taxonomy + traits ETL.
---------------------------------------
Inputs:
  - MDD_v2.3_6836species_Gliridae.csv
  - hmw-volume-6-gliridae.csv
  - gliridae_controlled_vocabulary.yml

Outputs (normalized tables, tidy-long, plus derived viz-ready views):
  - taxa.csv / taxa.parquet
  - names.csv / names.parquet
  - distributions_country.csv / distributions_country.parquet
  - traits_long.csv / traits_long.parquet
  - references.csv / references.parquet
  - taxon_reference_links.csv / taxon_reference_links.parquet
  - qa_name_matching.csv
  - viz_morphology_wide.csv / parquet
  - viz_habitat_diet_activity_onehot.csv / parquet
Optionally writes a DuckDB database (gliridae.duckdb) with all tables.
"""

from __future__ import annotations
import argparse
import hashlib
import os
import re
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

try:
    import duckdb  # optional but recommended
except Exception:
    duckdb = None

try:
    import yaml
except Exception as e:
    raise SystemExit("Missing dependency pyyaml. Install with: pip install pyyaml") from e


def _sha1(s: str) -> str:
    return hashlib.sha1(s.encode("utf-8")).hexdigest()


def slug_taxon(genus: str, species: str) -> str:
    return f"{str(genus).strip()}_{str(species).strip()}"


def clean_numeric_text(txt: str) -> str:
    """
    Heuristic cleanup for HMW numeric artifacts such as:
      - '18-5 mm'  -> '18.5 mm'
      - '11:3'     -> '11.3'
      - normalize em dashes to hyphen
    Keeps '90-91 mm' intact as a range (because second number has >=2 digits).
    """
    if txt is None or (isinstance(txt, float) and np.isnan(txt)):
        return ""
    t = str(txt)

    # normalize dashes
    t = t.replace("—", "-").replace("–", "-")

    # digit:digit -> digit.digit
    t = re.sub(r"(?<=\d):(?=\d)", ".", t)

    # decimal artifact: \d{1,3}-\d (single digit after hyphen) followed by non-digit
    t = re.sub(r"(\d{1,3})-(\d)(?=[^\d])", r"\1.\2", t)

    # common OCR bullet / odd characters
    t = t.replace("¢", "").replace("ﬁ", "fi").replace("ﬂ", "fl")

    return t


@dataclass
class ExtractedNumeric:
    trait: str
    unit: str
    vmin: Optional[float]
    vmax: Optional[float]
    excerpt: str


def _extract_range(pattern: str, text: str, unit: str, trait: str) -> Optional[ExtractedNumeric]:
    m = re.search(pattern, text, flags=re.I)
    if not m:
        return None
    g1 = m.group(1)
    g2 = m.group(2) if m.lastindex and m.lastindex >= 2 else None

    def to_float(x: Optional[str]) -> Optional[float]:
        if x is None:
            return None
        try:
            return float(x)
        except Exception:
            return None

    vmin = to_float(g1)
    vmax = to_float(g2) if g2 else None
    excerpt = m.group(0)[:160]
    return ExtractedNumeric(trait=trait, unit=unit, vmin=vmin, vmax=vmax, excerpt=excerpt)


def extract_morphometrics(descriptive_notes: str) -> List[ExtractedNumeric]:
    """
    Extract numeric morphometrics from HMW descriptiveNotes.
    Returns a list of ExtractedNumeric objects (min/max where possible).
    """
    t = clean_numeric_text(descriptive_notes)

    # Patterns capture: value OR value-value followed by unit
    # Keep patterns conservative (avoid overmatching).
    patterns = [
        (r"\bhead[- ]?body\s+(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?\s*mm", "mm", "head_body_mm"),
        (r"\btail\s+(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?\s*mm", "mm", "tail_mm"),
        (r"\bear\s+(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?\s*mm", "mm", "ear_mm"),
        (r"\bhind\s*foot\s+(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?\s*mm", "mm", "hindfoot_mm"),
        (r"\bhindfoot\s+(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?\s*mm", "mm", "hindfoot_mm"),
        (r"\bweight\s+(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?\s*g", "g", "weight_g"),
        (r"\bbody\s+weight\s+(\d+(?:\.\d+)?)(?:-(\d+(?:\.\d+)?))?\s*g", "g", "weight_g"),
        (r"\b2n\s*=\s*(\d+)\b", "count", "diploid_number_2n"),
    ]

    out: List[ExtractedNumeric] = []
    for pat, unit, trait in patterns:
        ex = _extract_range(pat, t, unit, trait)
        if ex:
            out.append(ex)
    return out


def load_vocab(vocab_path: str) -> dict:
    with open(vocab_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def compile_category_regex(vocab: dict) -> Dict[str, Dict[str, List[re.Pattern]]]:
    """
    Returns:
      {trait_name: {category: [compiled_regex...]}}
    """
    cat = vocab.get("traits", {}).get("categorical", {})
    compiled: Dict[str, Dict[str, List[re.Pattern]]] = {}
    for trait_name, obj in cat.items():
        compiled[trait_name] = {}
        for cat_name, cat_obj in obj.get("categories", {}).items():
            regs = [re.compile(rgx, flags=re.I) for rgx in cat_obj.get("regex", [])]
            compiled[trait_name][cat_name] = regs
    return compiled


def extract_categories(text: str, compiled: Dict[str, List[re.Pattern]]) -> List[Tuple[str, str]]:
    """
    Given text and compiled regex dict {category: [regex...]},
    return list of (category, excerpt) for categories present.
    """
    t = clean_numeric_text(text)
    out = []
    for category, regs in compiled.items():
        for rgx in regs:
            m = rgx.search(t)
            if m:
                start = max(0, m.start() - 50)
                end = min(len(t), m.end() + 50)
                excerpt = t[start:end].strip()
                out.append((category, excerpt))
                break
    return out


def build_references_from_strings(strings: List[str], source: str) -> pd.DataFrame:
    rows = []
    for s in strings:
        if s is None or (isinstance(s, float) and np.isnan(s)):
            continue
        st = str(s).strip()
        if not st:
            continue
        rid = _sha1(f"{source}::{st}")
        rows.append({"reference_id": rid, "reference_string": st, "source": source})
    return pd.DataFrame(rows).drop_duplicates("reference_id")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mdd", required=True, help="Path to MDD Gliridae CSV")
    ap.add_argument("--hmw", required=True, help="Path to HMW Gliridae CSV")
    ap.add_argument("--species_syn", default=None, help="Optional: Path to MDD Species_Syn v2.3 Gliridae CSV (species-rank names + types)")
    ap.add_argument("--vocab", required=True, help="Path to controlled vocabulary YAML")
    ap.add_argument("--outdir", required=True, help="Output directory")
    ap.add_argument("--duckdb", default="", help="Optional DuckDB file to write (e.g., gliridae.duckdb)")
    args = ap.parse_args()

    os.makedirs(args.outdir, exist_ok=True)

    vocab = load_vocab(args.vocab)
    overrides = vocab.get("name_harmonization", {}).get("overrides", {}) or {}
    compiled = compile_category_regex(vocab)

    mdd = pd.read_csv(args.mdd)
    hmw = pd.read_csv(args.hmw)

    species_syn = None
    if args.species_syn:
        species_syn = pd.read_csv(args.species_syn)

    # -------------------------
    # Taxa backbone (MDD)
    # -------------------------
    taxa = mdd.copy()
    taxa["canonical_key"] = taxa.apply(lambda r: slug_taxon(r["genus"], r["specificEpithet"]), axis=1)
    taxa["taxon_id"] = taxa["sciName"].apply(lambda x: f"MDD:{x}")

    taxa_cols = [
        "taxon_id","canonical_key","sciName","family","subfamily","genus","specificEpithet",
        "authoritySpeciesAuthor","authoritySpeciesYear","authorityParentheses","originalNameCombination",
        "authoritySpeciesCitation","authoritySpeciesLink",
        "typeVoucher","typeKind","typeVoucherURIs","typeLocality","typeLocalityLatitude","typeLocalityLongitude",
        "countryDistribution","continentDistribution","biogeographicRealm","iucnStatus",
        "taxonomyNotes","taxonomyNotesCitation"
    ]
    taxa = taxa[[c for c in taxa_cols if c in taxa.columns]].copy()

    # -------------------------
    # Names / synonymy (MDD nominalNames)
    # -------------------------
    names_rows = []
    if "nominalNames" in mdd.columns:
        for _, r in mdd.iterrows():
            taxon_id = f"MDD:{r['sciName']}"
            raw = r.get("nominalNames", "")
            if pd.isna(raw) or not str(raw).strip():
                continue
            for nm in str(raw).split("|"):
                nm = nm.strip()
                if not nm:
                    continue
                # crude status parse: anything in brackets as status/annotation
                status = None
                m = re.search(r"\[(.+?)\]\s*$", nm)
                if m:
                    status = m.group(1).strip()
                    nm_clean = re.sub(r"\s*\[(.+?)\]\s*$", "", nm).strip()
                else:
                    nm_clean = nm
                names_rows.append({
                    "taxon_id": taxon_id,
                    "name_string": nm_clean,
                    "name_annotation": status,
                    "source": "MDD",
                })
    names = pd.DataFrame(names_rows)

    # -------------------------
    # MDD Species_Syn v2.3 (species-rank names + types + synonymy)
    # -------------------------
    syn_names = pd.DataFrame()
    syn_status_long = pd.DataFrame()
    syn_usages = pd.DataFrame()
    name_reference_links = pd.DataFrame()
    refs_syn = pd.DataFrame()
    qa_syn_taxon_mapping = pd.DataFrame()
    syn_summary_by_taxon = pd.DataFrame()
    type_locality_points = pd.DataFrame()

    if species_syn is not None:
        ss = species_syn.copy()

        # Stable name identifier
        if "MDD_syn_ID" in ss.columns:
            ss["name_id"] = ss["MDD_syn_ID"].apply(lambda x: f"MDDSYN:{int(x)}" if pd.notna(x) else f"MDDSYN:{_sha1(str(x))}")
        else:
            ss["name_id"] = ss.apply(lambda r: f"MDDSYN:{_sha1(str(r.to_dict()))}", axis=1)

        # Map synonym records to accepted species in the MDD backbone via Genus + specific epithet.
        def _accepted_sciname(r):
            g = str(r.get("MDD_genus", "")).strip()
            sp = str(r.get("MDD_specificEpithet", "")).strip()
            if g and sp and g.lower() != "nan" and sp.lower() != "nan":
                return f"{g} {sp}"
            return None

        ss["accepted_sciName"] = ss.apply(_accepted_sciname, axis=1)
        ss["taxon_id"] = ss["accepted_sciName"].apply(lambda x: f"MDD:{x}" if isinstance(x, str) and x.strip() else None)

        def _split_pipe(v):
            if v is None or (isinstance(v, float) and np.isnan(v)):
                return []
            return [s.strip() for s in str(v).split("|") if s.strip()]

        # Expand (possibly multi-valued) nomenclature status
        status_rows = []
        for _, r in ss.iterrows():
            for st in _split_pipe(r.get("MDD_nomenclature_status", None)):
                status_rows.append({
                    "name_id": r["name_id"],
                    "taxon_id": r.get("taxon_id", None),
                    "nomenclature_status": st,
                    "source": "MDD_SpeciesSyn"
                })
        syn_status_long = pd.DataFrame(status_rows)

        # Build an exploded usages table + reference links
        usage_rows = []
        link_rows = []
        syn_ref_strings = []

        # Citation-like columns we also treat as reference strings (kept raw; hash-id in references)
        citation_cols = [
            ("MDD_authority_citation", "authority_citation"),
            ("MDD_unchecked_authority_citation", "unchecked_authority_citation"),
            ("MDD_sourced_unverified_citations", "sourced_unverified_citations"),
            ("MDD_variant_name_citations", "variant_name_citations"),
        ]

        for _, r in ss.iterrows():
            name_id = r["name_id"]
            taxon_id = r.get("taxon_id", None)

            # citation fields
            for col, role in citation_cols:
                v = r.get(col, None)
                if pd.notna(v) and str(v).strip():
                    st = str(v).strip()
                    syn_ref_strings.append(st)
                    link_rows.append({
                        "name_id": name_id,
                        "taxon_id": taxon_id,
                        "reference_id": _sha1(f"MDD_SpeciesSyn::{st}"),
                        "reference_string": st,
                        "role": role,
                        "source": "MDD_SpeciesSyn"
                    })

            # name usages (pipe-separated)
            for u in _split_pipe(r.get("MDD_name_usages", None)):
                usage_id = _sha1(f"{name_id}::usage::{u}")
                usage_rows.append({
                    "usage_id": usage_id,
                    "name_id": name_id,
                    "taxon_id": taxon_id,
                    "usage_string": u,
                    "source": "MDD_SpeciesSyn"
                })
                syn_ref_strings.append(u)
                link_rows.append({
                    "name_id": name_id,
                    "taxon_id": taxon_id,
                    "reference_id": _sha1(f"MDD_SpeciesSyn::{u}"),
                    "reference_string": u,
                    "role": "name_usage",
                    "source": "MDD_SpeciesSyn"
                })

        syn_usages = pd.DataFrame(usage_rows)
        name_reference_links = pd.DataFrame(link_rows).drop_duplicates()

        # References derived from synonym dataset
        refs_syn = build_references_from_strings(syn_ref_strings, source="MDD_SpeciesSyn")

        # Wide nomenclature table (keep original columns, add name_id + taxon_id)
        keep_cols = ["name_id", "taxon_id"]
        keep_cols += [c for c in ss.columns if c not in keep_cols]
        syn_names = ss[keep_cols].copy()

        # QA: mapping success to backbone taxa
        backbone_taxa = set(taxa["taxon_id"].astype(str).tolist())
        qa_syn_taxon_mapping = (syn_names[["name_id", "taxon_id", "accepted_sciName"]]
                                .assign(mapped_to_backbone=lambda d: d["taxon_id"].isin(backbone_taxa))
                                .groupby(["mapped_to_backbone"])
                                .size()
                                .reset_index(name="n_names"))

    # Summary per accepted taxon (useful for plotting)
    def _safe_year(x):
        try:
            return int(x)
        except Exception:
            return np.nan

    ss["_year_int"] = ss["MDD_year"].apply(_safe_year) if "MDD_year" in ss.columns else np.nan

    syn_summary_by_taxon = (ss.groupby("taxon_id", dropna=False)
        .agg(
            n_name_records=("name_id", "nunique"),
            n_species_valid=("MDD_validity", lambda x: int((x.astype(str) == "species").sum())),
            n_synonyms=("MDD_validity", lambda x: int((x.astype(str) == "synonym").sum())),
            n_nomen_dubium=("MDD_validity", lambda x: int((x.astype(str) == "nomen_dubium").sum())),
            earliest_year=("_year_int", "min"),
            latest_year=("_year_int", "max"),
            n_with_type_locality=("MDD_original_type_locality", lambda x: int(pd.notna(x).sum())),
            n_with_type_coords=("MDD_type_latitude", lambda x: int(pd.notna(x).sum())),
            n_with_holotype=("MDD_holotype", lambda x: int(pd.notna(x).sum())),
        )
        .reset_index()
    )

    # Map-ready subset (only rows with coordinates)
    if "MDD_type_latitude" in ss.columns and "MDD_type_longitude" in ss.columns:
        type_locality_points = (ss[pd.notna(ss["MDD_type_latitude"]) & pd.notna(ss["MDD_type_longitude"])]
            .copy()
        )


    # -------------------------
    # Distributions (country list from MDD)
    # -------------------------
    dist_rows = []
    for _, r in taxa.iterrows():
        taxon_id = r["taxon_id"]
        raw = r.get("countryDistribution", "")
        if pd.isna(raw) or not str(raw).strip():
            continue
        for c in str(raw).split("|"):
            c = c.strip()
            if not c:
                continue
            dist_rows.append({"taxon_id": taxon_id, "country_name_raw": c, "source": "MDD"})
    distributions_country = pd.DataFrame(dist_rows)

    # -------------------------
    # HMW name harmonization + QA
    # -------------------------
    hmw = hmw.copy()
    hmw["hmw_key_raw"] = hmw.apply(lambda r: slug_taxon(r.get("interpretedGenus",""), r.get("interpretedSpecies","")), axis=1)

    # Apply overrides on raw key where needed
    def apply_override(row):
        key = row["hmw_key_raw"]
        # If species missing, try from name string
        if key.endswith("_nan") or key.endswith("_None") or "_nan" in key:
            name = str(row.get("name","")).strip()
            # name is usually "Genus species"
            parts = name.split()
            if len(parts) >= 2:
                key = slug_taxon(parts[0], parts[1])
        # override (handles typo cases)
        return overrides.get(key, key)

    hmw["canonical_key"] = hmw.apply(apply_override, axis=1)

    # Join to taxa
    hmw_join = hmw.merge(taxa[["taxon_id","canonical_key"]], on="canonical_key", how="left", validate="m:1")
    qa = hmw_join[["name","interpretedGenus","interpretedSpecies","hmw_key_raw","canonical_key","taxon_id"]].copy()
    qa["match_status"] = np.where(qa["taxon_id"].notna(), "matched_to_MDD", "unmatched")

    # -------------------------
    # Traits (tidy-long)
    # -------------------------
    trait_rows = []

    # categorical extractions: pick appropriate HMW fields
    field_map = {
        "habitat_class": "habitat",
        "diet_class": "foodAndFeeding",
        "activity_rhythm": "activityPatterns",
        "dormancy": "activityPatterns",
        "locomotion": "movementsHomeRangeAndSocialOrganization",
        "sociality": "movementsHomeRangeAndSocialOrganization",
    }

    for _, r in hmw_join.iterrows():
        taxon_id = r.get("taxon_id")
        if pd.isna(taxon_id) or not str(taxon_id).strip():
            continue  # keep backbone-driven; unmatched can be handled later
        taxon_id = str(taxon_id)

        # numeric morphometrics
        num = extract_morphometrics(r.get("descriptiveNotes",""))
        for ex in num:
            # store min and max separately (more viz-friendly)
            if ex.vmin is not None:
                trait_rows.append({
                    "taxon_id": taxon_id,
                    "trait_group": "morphology",
                    "trait_name": f"{ex.trait}_min" if ex.vmax is not None else ex.trait,
                    "trait_value": ex.vmin,
                    "trait_unit": ex.unit,
                    "value_type": "numeric",
                    "source": "HMW",
                    "source_field": "descriptiveNotes",
                    "verbatim_excerpt": ex.excerpt,
                    "confidence": "high",
                })
            if ex.vmax is not None:
                trait_rows.append({
                    "taxon_id": taxon_id,
                    "trait_group": "morphology",
                    "trait_name": f"{ex.trait}_max",
                    "trait_value": ex.vmax,
                    "trait_unit": ex.unit,
                    "value_type": "numeric",
                    "source": "HMW",
                    "source_field": "descriptiveNotes",
                    "verbatim_excerpt": ex.excerpt,
                    "confidence": "high",
                })

        # categorical traits
        for trait_name, field in field_map.items():
            text = r.get(field, "")
            if trait_name not in compiled:
                continue
            hits = extract_categories(text, compiled[trait_name])
            for category, excerpt in hits:
                trait_rows.append({
                    "taxon_id": taxon_id,
                    "trait_group": trait_name,
                    "trait_name": trait_name,
                    "trait_value": category,
                    "trait_unit": "",
                    "value_type": "category",
                    "source": "HMW",
                    "source_field": field,
                    "verbatim_excerpt": excerpt[:200],
                    "confidence": "medium",
                })

    traits_long = pd.DataFrame(trait_rows)

    # -------------------------
    # References + links
    # -------------------------
    # MDD: authoritySpeciesCitation & taxonomyNotesCitation
    mdd_refs = []
    if "authoritySpeciesCitation" in mdd.columns:
        mdd_refs.extend([x for x in mdd["authoritySpeciesCitation"].tolist() if pd.notna(x)])
    if "taxonomyNotesCitation" in mdd.columns:
        mdd_refs.extend([x for x in mdd["taxonomyNotesCitation"].tolist() if pd.notna(x)])

    refs_mdd = build_references_from_strings(mdd_refs, source="MDD")

    # HMW: bibliography (pipe-separated)
    hmw_ref_strings = []
    for b in hmw.get("bibliography", pd.Series(dtype=str)).fillna("").tolist():
        if not str(b).strip():
            continue
        for part in str(b).split("|"):
            st = part.strip()
            if st:
                hmw_ref_strings.append(st)
    refs_hmw = build_references_from_strings(hmw_ref_strings, source="HMW")

    references = pd.concat([refs_mdd, refs_hmw, refs_syn], ignore_index=True).drop_duplicates("reference_id")

    # Link references to taxa (MDD: one-to-one; HMW: from bibliography per species)
    links = []

    # MDD authority and taxonomy notes
    for _, r in mdd.iterrows():
        taxon_id = f"MDD:{r['sciName']}"
        if pd.notna(r.get("authoritySpeciesCitation", None)):
            rid = _sha1(f"MDD::{str(r['authoritySpeciesCitation']).strip()}")
            links.append({"taxon_id": taxon_id, "reference_id": rid, "role": "original_description_or_authority", "source": "MDD"})
        if pd.notna(r.get("taxonomyNotesCitation", None)):
            rid = _sha1(f"MDD::{str(r['taxonomyNotesCitation']).strip()}")
            links.append({"taxon_id": taxon_id, "reference_id": rid, "role": "taxonomy_notes", "source": "MDD"})

    # HMW bibliography
    # join HMW rows to taxon_id via canonical_key
    hmw2 = hmw_join[["taxon_id","bibliography"]].copy()
    for _, r in hmw2.iterrows():
        taxon_id = r.get("taxon_id")
        if pd.isna(taxon_id):
            continue
        bib = str(r.get("bibliography","") or "").strip()
        if not bib:
            continue
        for part in bib.split("|"):
            st = part.strip()
            if not st:
                continue
            rid = _sha1(f"HMW::{st}")
            links.append({"taxon_id": str(taxon_id), "reference_id": rid, "role": "hmw_bibliography", "source": "HMW"})

    taxon_reference_links = pd.DataFrame(links).drop_duplicates()

    # -------------------------
    # Derived viz views
    # -------------------------
    # Morphology wide
    morph = traits_long[traits_long["trait_group"].eq("morphology") & traits_long["value_type"].eq("numeric")].copy()
    viz_morph_wide = (
        morph.pivot_table(index="taxon_id", columns="trait_name", values="trait_value", aggfunc="first")
        .reset_index()
    )

    # One-hot for main categorical groups
    cats = traits_long[traits_long["value_type"].eq("category")].copy()
    if not cats.empty:
        cats["one"] = 1
        viz_onehot = (
            cats.pivot_table(index="taxon_id", columns=["trait_name","trait_value"], values="one", aggfunc="max", fill_value=0)
        )
        viz_onehot.columns = [f"{a}__{b}" for a,b in viz_onehot.columns]
        viz_onehot = viz_onehot.reset_index()
    else:
        viz_onehot = pd.DataFrame({"taxon_id": taxa["taxon_id"].unique()})

    # -------------------------
    # Write outputs
    # -------------------------
    def write_both(df: pd.DataFrame, base: str):
        csv_path = os.path.join(args.outdir, base + ".csv")
        pq_path  = os.path.join(args.outdir, base + ".parquet")
        df.to_csv(csv_path, index=False)
        try:
            df.to_parquet(pq_path, index=False)
        except Exception:
            # Parquet optional
            pass

    traits_long = traits_long.drop_duplicates()

    write_both(taxa, "taxa")
    write_both(names, "names")
    write_both(distributions_country, "distributions_country")
    write_both(traits_long, "traits_long")
    write_both(references, "references")
    write_both(taxon_reference_links, "taxon_reference_links")
    write_both(qa, "qa_name_matching")
    write_both(viz_morph_wide, "viz_morphology_wide")
    write_both(viz_onehot, "viz_habitat_diet_activity_onehot")

    # Species_Syn (optional)
    if species_syn is not None:
        write_both(syn_names, "mdd_species_syn_names")
        write_both(syn_status_long, "mdd_species_syn_status_long")
        write_both(syn_usages, "mdd_species_syn_usages")
        write_both(name_reference_links, "name_reference_links")
        write_both(qa_syn_taxon_mapping, "qa_species_syn_taxon_mapping")
        write_both(syn_summary_by_taxon, "mdd_species_syn_summary_by_taxon")
        write_both(type_locality_points, "mdd_species_syn_type_locality_points")

    # DuckDB (optional)
    if args.duckdb:
        if duckdb is None:
            raise SystemExit("duckdb is not installed. Install with: pip install duckdb")
        db_path = args.duckdb
        con = duckdb.connect(db_path)

        def _store_df(name: str, df: pd.DataFrame):
            con.register(name, df)
            con.execute(f'CREATE OR REPLACE TABLE "{name}" AS SELECT * FROM "{name}"')

        _store_df("taxa", taxa)
        _store_df("names", names)
        _store_df("distributions_country", distributions_country)
        _store_df("traits_long", traits_long)
        _store_df("references", references)
        _store_df("taxon_reference_links", taxon_reference_links)
        _store_df("viz_morphology_wide", viz_morph_wide)
        _store_df("viz_onehot", viz_onehot)

        if species_syn is not None:
            _store_df("mdd_species_syn_names", syn_names)
            _store_df("mdd_species_syn_status_long", syn_status_long)
            _store_df("mdd_species_syn_usages", syn_usages)
            _store_df("name_reference_links", name_reference_links)
            _store_df("qa_species_syn_taxon_mapping", qa_syn_taxon_mapping)
            _store_df("mdd_species_syn_summary_by_taxon", syn_summary_by_taxon)
            _store_df("mdd_species_syn_type_locality_points", type_locality_points)

        con.close()

    print("Done.")
    print(f"Taxa (MDD): {len(taxa)}")
    print(f"HMW rows: {len(hmw)}")
    print(f"Traits (long): {len(traits_long)}")
    print("Name matching status:")
    print(qa["match_status"].value_counts(dropna=False).to_string())


if __name__ == "__main__":
    main()
