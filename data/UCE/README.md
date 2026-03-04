# data/UCE — Ultraconserved Element Data

Assembled and aligned ultraconserved element (UCE) loci for all sequenced *Graphiurus* specimens, generated using the `phyluce` pipeline with the Tetrapod UCE 5k probe set.

## Files and Directories

| Path | Size | Description |
|---|---|---|
| `UCE_spades_assembly_contigs/` | 11–17 MB per sample | Per-sample SPAdes contig assemblies (one FASTA per specimen) |
| `aligned_trimmed_cleannames_N4452/` | ~201 MB unpacked | 4,452 trimmed, edge-cleaned, renamed UCE loci (FASTA) |
| `alignment_files.zip` | ~149 MB | Compressed archive of the aligned_trimmed_cleannames set |
| `uce-5k-probes.fasta` | ~1.1 MB | Tetrapod UCE 5k probe set (Faircloth et al. 2012) |
| `Tetrapods-UCE-5Kv1.fasta` | ~1.1 MB | Alternative copy of probe set |

## How These Files Were Generated

1. **Assembly:** Raw reads → SPAdes assembly per specimen (via `phyluce_assembly_assemblo_spades`)
2. **UCE matching:** Contigs matched to 5k probe set (via `phyluce_assembly_match_contigs_to_probes`)
3. **Extraction:** UCE loci extracted from matched contigs (via `phyluce_assembly_get_fastas_from_match_counts`)
4. **Alignment:** Per-locus MAFFT alignment (via `phyluce_align_seqcap_align`)
5. **Trimming:** Edge trimming and Gblocks cleaning (via `phyluce_align_get_gblocks_trimmed_alignments_from_untrimmed`)
6. **Cleaning:** Taxon name cleaning and renaming (via `phyluce_align_remove_locus_name_from_nexus_lines`)

The full pipeline script is at `scripts/UCE_pipeline.sh`.

## Filtered Working Sets

The `aligned_trimmed_cleannames_N4452/` directory contains all 4,452 loci. For analyses, subsets were filtered by taxon coverage and parsimony-informative sites (PIC):

| Filter | Loci | Used in |
|---|---|---|
| ≥95% coverage + ≥10% PIC | 1,155 | Species tree (ASTRAL), Bayesian (BEAST2) — main analyses |
| ≥90% coverage + ≥10% PIC | ~1,800 | Divergence dating (BEAST2) |
| ≥80% coverage | ~2,400 | Sensitivity analyses |

Filtered subsets were generated with `analyses/01_phylogenetics/02_UCE/PIC_subsampler_modified.py`.

## Probe Set Citation

Faircloth, B.C., et al. (2012). Ultraconserved elements anchor thousands of genetic markers spanning multiple evolutionary timescales. *Systematic Biology*, 61(5), 717–726. https://doi.org/10.1093/sysbio/sys004
