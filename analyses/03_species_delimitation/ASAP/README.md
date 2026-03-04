# ASAP — Assemble Species by Automatic Partitions

Results from ASAP (Automatic Sequence/Barcode/Species Partitions) species delimitation applied to the full *Graphiurus* CYTB alignment.

## Method

ASAP was run via the web server at https://bioinfo.mnhn.fr/abi/public/asap/ using the K80 (Kimura 2-parameter) substitution model. The analysis generates ranked partitions by evaluating barcode gaps in pairwise distance distributions.

Reference: Puillandre, N., Brouillet, S. & Achaz, G. (2021). ASAP: Assemble Species by Automatic Partitions. *Molecular Ecology Resources*, 21, 609–620.

## Files

| File | Description |
|---|---|
| `Full.fas` | Full CYTB alignment submitted to ASAP (FASTA) |
| `Full.Partition_1–20.txt` | 20 ranked alternative species partitions |
| `Full.Partition_1–20.csv` | Same partitions in CSV format |
| `Full.spart` | SPART format file (all partitions) |
| `Full.spart.xml` | XML version of SPART file |
| `asap.log` | ASAP run log with scoring details |
| `*.svg` | Barcode gap visualizations (groups, histogram, partitions, ranks, scores, species) |

## Results

ASAP generated 20 alternative partitions. The top-scoring partition and a consensus across all four delimitation methods used in this study support **24 MOTUs** in *Graphiurus*.
