#!/bin/bash
# Script to find the latest checkpoint directory

if [ -z "$1" ]; then
    echo "Usage: $0 <checkpoint_base_dir>"
    echo "Example: $0 ../results/test_openvla/checkpoints"
    exit 1
fi

CHECKPOINT_DIR="$1"

if [ ! -d "$CHECKPOINT_DIR" ]; then
    echo "Error: Checkpoint directory '$CHECKPOINT_DIR' does not exist"
    exit 1
fi

# Find the latest checkpoint by extracting step numbers and sorting
LATEST=$(find "$CHECKPOINT_DIR" -maxdepth 1 -type d -name "global_step_*" | \
    sed 's/.*global_step_//' | \
    sort -n | \
    tail -1)

if [ -z "$LATEST" ]; then
    echo "No checkpoints found in $CHECKPOINT_DIR"
    exit 1
fi

LATEST_DIR="${CHECKPOINT_DIR}/global_step_${LATEST}"
echo "Latest checkpoint: $LATEST_DIR"
echo ""
echo "Add this to your config YAML:"
echo "runner:"
echo "  resume_dir: \"$LATEST_DIR\""

