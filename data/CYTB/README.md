# data/CYTB — Cytochrome B Alignments

Aligned cytochrome B (CYTB) sequences for all sampled *Graphiurus* specimens and Gliridae outgroups, ready for use in phylogenetic analyses.

## Files

| File | Sequences | Type | Description |
|---|---|---|---|
| `CYTB_full_NT_N341.fas` | 341 | Nucleotide FASTA | Full dataset — all specimens and outgroups |
| `CYTB_thinned_NT_N130.fas` | 130 | Nucleotide FASTA | Thinned dataset (≤95% pairwise similarity) for faster ML/Bayesian runs |
| `CYTB_thinned_AA_N130.fas` | 130 | Amino acid FASTA | Protein translation of the thinned dataset |

## Taxon Naming

Sequence headers follow the format `Genus_species_specimenID_locality`. Outgroup taxa (other Gliridae genera) are included in the full dataset. The thinned dataset retains representative specimens per locality cluster.

## Usage

```bash
# ML inference (full dataset)
iqtree2 -s CYTB_full_NT_N341.fas -m MFP --ufboot 1000 --alrt 1000 -T AUTO

# ML inference (thinned dataset)
iqtree2 -s CYTB_thinned_NT_N130.fas -m MFP --ufboot 1000 --alrt 1000 -T AUTO
```

For BEAST2 and MrBayes, use the pre-configured XML/NEXUS files in `analyses/01_phylogenetics/01_CYTB/`.

## Alignment Details

- Alignment method: MAFFT (L-INS-i)
- Gene length: ~1,143 bp (standard CYTB)
- Partitioned by codon position (1st+2nd / 3rd) for model-based analyses
