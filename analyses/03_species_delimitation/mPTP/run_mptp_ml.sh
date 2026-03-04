#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# mPTP species delimitation (ML, multi-rate)
#
# Usage:
#   chmod +x run_mptp_ml.sh
#
#   ./run_mptp_ml.sh path/to/mltree.nwk
#   # or
#   TREE_FILE=path/to/mltree.nwk ./run_mptp_ml.sh
#
# Optional environment overrides:
#   RUN_ROOT=mptp_results
#   RUN_ID=20260304_123000
#   OUT_PREFIX=ml
#   MULTI=1
# -----------------------------------------------------------------------------

TREE_FILE="${1:-${TREE_FILE:-}}"
RUN_ROOT="${RUN_ROOT:-mptp_results}"
RUN_ID="${RUN_ID:-$(date +%Y%m%d_%H%M%S)}"
RUN_DIR="${RUN_ROOT}/${RUN_ID}"
OUT_PREFIX="${OUT_PREFIX:-ml}"

MULTI="${MULTI:-1}"

if ! command -v mptp >/dev/null 2>&1; then
  echo "ERROR: mptp not found in PATH. Please install mPTP and try again." >&2
  exit 127
fi

if [[ -z "${TREE_FILE}" ]]; then
  echo "ERROR: TREE_FILE not provided." >&2
  echo "Usage: $0 path/to/mltree.nwk" >&2
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

{
  echo "# mPTP ML run provenance"
  echo "date:        $(date -Is)"
  echo "cwd:         $(pwd)"
  echo "host:        $(hostname 2>/dev/null || echo NA)"
  echo "tree_file:   ${TREE_FILE}"
  if command -v sha256sum >/dev/null 2>&1; then
    echo "tree_sha256: $(sha256sum "${TREE_FILE}" | awk '{print $1}')"
  fi
  echo -n "mptp_version: "
  (mptp --version 2>/dev/null || mptp -v 2>/dev/null || echo "unknown") | head -n 1
  echo "multi:       ${MULTI}"
  echo
  echo "# Command:"
  echo -n "mptp --ml "
  [[ "${MULTI}" -eq 1 ]] && echo -n "--multi "
  echo "--tree_file \"${TREE_FILE}\" --output_file \"${OUT_FILE}\""
} | tee "${PROV}" > /dev/null

cmd=( mptp
      --ml
      --tree_file "${TREE_FILE}"
      --output_file "${OUT_FILE}" )

if [[ "${MULTI}" -eq 1 ]]; then
  cmd+=( --multi )
fi

echo "[mPTP] Running ML..." | tee "${LOG}"
"${cmd[@]}" 2>&1 | tee -a "${LOG}"

echo
echo "Done."
echo "Run directory: ${RUN_DIR}"
echo "Outputs prefix: ${OUT_FILE}"
echo "Log: ${LOG}"
echo "Provenance: ${PROV}"