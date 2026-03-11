#!/bin/bash

set -euo pipefail

########################################
# USER CONFIGURATION
########################################

# GPU to use
GPU_ID=${GPU_ID:-0}

# Input directory containing SMILES txt files
INPUT_DIR=${INPUT_DIR:-"./data/FDA_drugs/reasyn_inputs"}

# Output directory
OUTPUT_DIR=${OUTPUT_DIR:-"./results/reasyn_outputs"}

# Path to ReaSyn model checkpoint
MODEL=${MODEL:-"./models/reasyn/model.ckpt"}

# ReaSyn script location
REASYN_SCRIPT=${REASYN_SCRIPT:-"sample.py"}

# Parameters
EXHAUSTIVENESS=${EXHAUSTIVENESS:-20}
TIMEOUT_MIN=${TIMEOUT_MIN:-10}

########################################

export CUDA_VISIBLE_DEVICES=$GPU_ID

LOG_DIR="${OUTPUT_DIR}/logs"
FAILED_LOG="${OUTPUT_DIR}/failed.txt"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

touch "$FAILED_LOG"

echo "--------------------------------------"
echo "ReaSyn Batch Runner"
echo "GPU: $GPU_ID"
echo "Input directory: $INPUT_DIR"
echo "Output directory: $OUTPUT_DIR"
echo "--------------------------------------"

for txt in "$INPUT_DIR"/*.txt; do

    base=$(basename "$txt" .txt)

    out_csv="${OUTPUT_DIR}/${base}.csv"
    out_tmp="${out_csv}.tmp"

    log_out="${LOG_DIR}/${base}.out"
    log_err="${LOG_DIR}/${base}.err"

    # Skip completed molecules
    if [[ -s "$out_csv" ]]; then
        echo "[SKIP] $base already completed"
        continue
    fi

    echo "[RUN] $base"

    timeout ${TIMEOUT_MIN}m \
    python -u "$REASYN_SCRIPT" \
        -i "$txt" \
        -o "$out_tmp" \
        -m "$MODEL" \
        --reward_model jnk3 \
        --exhaustiveness $EXHAUSTIVENESS \
        --num_gpus 1 \
        --num_workers_per_gpu 1 \
        > "$log_out" 2> "$log_err"

    STATUS=$?

    if [[ $STATUS -ne 0 || ! -s "$out_tmp" ]]; then
        echo "[FAILED] $base"
        echo "$base" >> "$FAILED_LOG"
        rm -f "$out_tmp"
        continue
    fi

    mv "$out_tmp" "$out_csv"

    echo "[DONE] $base"

done

echo "--------------------------------------"
echo "ReaSyn run finished"
echo "--------------------------------------"