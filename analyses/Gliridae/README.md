# Gliridae — Family-Level Analyses

Phylogenetic and diversity analyses spanning the entire Gliridae family, providing the broader evolutionary context for *Graphiurus*. This directory uses a family-level CYTB alignment including all extant Gliridae genera (*Graphiurus*, *Glis*, *Muscardinus*, *Dryomys*, *Myomimus*, and relatives).

## Key Finding

*Graphiurus* is recovered as sister to all other extant Gliridae genera — the earliest-diverging lineage within the family. Genetic distances between the two major *Graphiurus* clades (West African vs. pan-sub-Saharan) are equal to or greater than those used to distinguish genera elsewhere in Gliridae.

## Directory Structure

```
Gliridae/
├── ML_iqtree/              # IQ-TREE2 ML analysis
│   ├── gliridae_cytb.fas   # Family-level CYTB alignment (FASTA)
│   ├── *.partition.txt     # Codon-position partition definitions
│   └── *.log               # IQ-TREE run logs (partitioned and unpartitioned)
├── BI_beast/               # BEAST2 Bayesian inference
│   └── gliridae_cytb.xml   # BEAST2 XML — family phylogeny
├── BI_dating/              # BEAST2 molecular clock (two independent runs)
│   ├── gliridae_cytb-r1.xml
│   └── gliridae_cytb-r2.xml
├── DnaSP/                  # Nucleotide diversity statistics
│   ├── Family/
│   ├── Subfamily/
│   ├── Genus/
│   └── NT/
└── MEGA/
    └── Gliridae_AllCytb.mdsx   # MEGA project file (all Gliridae CYTB sequences)
```

## Running the Analyses

**ML tree (IQ-TREE2):**
```bash
cd ML_iqtree/
iqtree2 -s gliridae_cytb.fas -p partition.txt -m MFP+MERGE --ufboot 1000 --alrt 1000 -T AUTO
```

**Bayesian tree (BEAST2):**
```bash
beast BI_beast/gliridae_cytb.xml
```

**Divergence dating — two independent BEAST2 runs:**
```bash
beast BI_dating/gliridae_cytb-r1.xml &
beast BI_dating/gliridae_cytb-r2.xml &
# After convergence: combine with LogCombiner, then summarise with TreeAnnotator
```
