# 02 — Divergence Dating

Molecular clock analyses to estimate divergence times across *Graphiurus* and the broader Gliridae. BEAST2 is used with relaxed uncorrelated log-normal clocks and fossil calibrations applied to outgroup nodes.

## Directory Structure

```
02_divergence_dating/
├── CYTB/
│   └── graph_cytb.xml            # BEAST2 XML for CYTB clock analysis
├── UCE/
│   └── graph_uce_aln.xml         # BEAST2 XML for UCE clock analysis
```

## Running the Analyses

```bash
# CYTB divergence dating
beast CYTB/graph_cytb.xml

# UCE divergence dating
beast UCE/graph_uce_aln.xml
```

**Note:** BEAST2 runs are computationally intensive. For the UCE dataset (larger matrix), parallel chains or BEAGLE GPU acceleration are recommended.

## Fossil Calibrations

Fossil calibrations are embedded in the XML files as prior distributions on divergence nodes within Gliridae. Refer to the published paper (Onditi et al. 2026, doi:10.1016/j.ympev.2026.108549) for full calibration justifications.

## Outputs

BEAST2 generates `.trees`, `.log`, and `.ops` files per run. These are excluded from git (see `.gitignore`) but are reproducible. Final summary trees (maximum-clade-credibility trees) should be generated with TreeAnnotator after confirming convergence in Tracer (ESS > 200 for all parameters).
