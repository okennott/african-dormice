# 06 — Genetic Diversity

Population-level genetic diversity analyses for *Graphiurus* MOTUs using CYTB sequences. Three software environments are used: DnaSP (diversity statistics), MEGA (pairwise distances), and popART (haplotype network visualization).

## Directory Structure

```
06_genetic_diversity/
├── DnaSP/
│   ├── alignment_withMOTUblocks.nex                          # Full alignment with MOTU block definitions
│   └── alignment_withMOTUblocks_Aethoglis_vs_Graphiurus.nex # Genus-level comparison alignment
├── MEGA/
│   └── Gliridae_AllCytb.mdsx                                 # MEGA project file (all CYTB sequences)
└── popART/
    ├── MOTU10.csv / MOTU10.nex                               # Per-MOTU alignment + metadata
    ├── MOTU11.csv / MOTU11.nex
    └── (additional per-MOTU files)
```

## Analyses

### DnaSP — Nucleotide Diversity

Used to calculate per-MOTU nucleotide diversity (π), haplotype diversity (Hd), and Tajima's D. NEXUS files include `BLOCK SETS` defining MOTU groups for sliding-window and per-group statistics.

Open in DnaSP v6:
```
File → Open Data File → alignment_withMOTUblocks.nex
```

### MEGA — Pairwise Distances

Used to compute mean intragroup (within-MOTU) and intergroup (between-MOTU) Kimura 2-parameter (K2P) distances, as reported in the species delimitation section of the paper.

Open project in MEGA11:
```
File → Open → Gliridae_AllCytb.mdsx
Analysis → Compute Pairwise Distances → K2P model
```

### popART — Haplotype Networks

TCS parsimony networks were generated per MOTU for visual inspection of intraspecific variation and geographic structure. Each MOTU subdirectory contains:
- `.nex` — NEXUS alignment with trait blocks for geographic colouring
- `.csv` — Haplotype frequency and metadata table

Open in popART:
```
File → Open → [MOTU].nex
Network → TCS Network
```

## Key Results

- 24 MOTUs recovered: 21 in the pan-sub-Saharan clade, 3 in the West African clade
- Inter-MOTU K2P distances comparable to or exceeding intergeneric distances in Gliridae
- Most MOTUs show low haplotype diversity, consistent with recent Plio-Pleistocene divergence
