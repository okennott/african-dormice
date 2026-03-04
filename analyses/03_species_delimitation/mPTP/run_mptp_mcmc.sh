#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# mPTP species delimitation (MCMC, multi-rate)
#
# What it does:
#   - Runs mPTP in MCMC mode with --multi
#   - Writes outputs into a run-specific directory with a clear prefix
#   - Records provenance (date, cwd, tool version if available, command)
#
# Usage:
#   chmod +x run_mptp_mcmc_multi.sh
#
#   # Provide tree as an argument:
#   ./run_mptp_mcmc.sh path/to/bitree.nwk
#
#   # Or via env:
#   TREE_FILE=path/to/bitree.nwk ./run_mptp_mcmc.sh
#
# Optional environment overrides:
#   RUN_ROOT=mptp_results
#   RUN_ID=20260304_123000
#   OUT_PREFIX=mcmc
#   MULTI=1                     # 1 => include --multi, 0 => omit
#   MCMC_ITERS=50000000
#   MCMC_SAMPLE=1000000
#   MCMC_BURNIN=1000000
# -----------------------------------------------------------------------------

TREE_FILE="${1:-${TREE_FILE:-}}"
RUN_ROOT="${RUN_ROOT:-mptp_results}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
RUN_DIR="${RUN_ROOT}/${RUN_ID}"
OUT_PREFIX="${OUT_PREFIX:-mcmc}"

MULTI="${MULTI:-1}"
MCMC_ITERS="${MCMC_ITERS:-50000000}"
MCMC_SAMPLE="${MCMC_SAMPLE:-1000000}"
MCMC_BURNIN="${MCMC_BURNIN:-1000000}"

# ---- Pre-flight checks -------------------------------------------------------
if ! command -v mptp >/dev/null 2>&1; then
  echo "ERROR: mptp not found in PATH. Please install mPTP and try again." >&2
  exit 127
fi

if [[ -z "${TREE_FILE}" ]]; then
  echo "ERROR: TREE_FILE not provided." >&2
  echo "Usage: $0 path/to/bitree.nwk" >&2
  exit 2
fi

if [[ ! -s "${TREE_FILE}" ]]; then
  echo "ERROR: Tree file not found or empty: ${TREE_FILE}" >&2
  exit 2
fi

mkdir -p "${RUN_DIR}"

OUT_FILE="${RUN_DIR}/${OUT_PREFIX}"
LOG="${OUT_FILE}.run.log"
PROV="${OUT_FILE}.provenance.txt"

# ---- Provenance --------------------------------------------------------------
{
  echo "# mPTP MCMC run provenance"
  echo "date:        $(date -Is)"
  echo "cwd:         $(pwd)"
  echo "host:        $(hostname 2>/dev/null || echo NA)"
  echo "tree_file:   ${TREE_FILE}"
  if command -v sha256sum >/dev/null 2>&1; then
    echo "tree_sha256: $(sha256sum "${TREE_FILE}" | awk '{print $1}')"
  fi
  # Try common version flags
  echo -n "mptp_version: "
  (mptp --version 2>/dev/null || mptp -v 2>/dev/null || echo "unknown") | head -n 1
  echo "mcmc_iters:  ${MCMC_ITERS}"
  echo "mcmc_sample: ${MCMC_SAMPLE}"
  echo "mcmc_burnin: ${MCMC_BURNIN}"
  echo "multi:       ${MULTI}"
  echo
  echo "# Command:"
  echo -n "mptp --mcmc ${MCMC_ITERS} "
  [[ "${MULTI}" -eq 1 ]] && echo -n "--multi "
  echo "--mcmc_sample ${MCMC_SAMPLE} --mcmc_burnin ${MCMC_BURNIN} --tree_file \"${TREE_FILE}\" --output_file \"${OUT_FILE}\""
} | tee "${PROV}" > /dev/null

# ---- Build command -----------------------------------------------------------
cmd=( mptp
      --mcmc "${MCMC_ITERS}"
      --mcmc_sample "${MCMC_SAMPLE}"
      --mcmc_burnin "${MCMC_BURNIN}"
      --tree_file "${TREE_FILE}"
      --output_file "${OUT_FILE}" )

if [[ "${MULTI}" -eq 1 ]]; then
  cmd+=( --multi )
fi

# ---- Run ---------------------------------------------------------------------
echo "[mPTP] Running MCMC..." | tee "${LOG}"
"${cmd[@]}" 2>&1 | tee -a "${LOG}"

echo
echo "Done."
echo "Run directory: ${RUN_DIR}"
echo "Outputs prefix: ${OUT_FILE}"
echo "Log: ${LOG}"
echo "Provenance: ${PROV}"