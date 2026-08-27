#!/bin/bash

## ./scripts/generate_and_plot.sh ee_ee ee_mumu

set -e

for PROCESS in "$@"; do
    echo "========================================"
    echo "Generating process: $PROCESS"
    echo "========================================"

    bash ./scripts/generation.sh "scripts/processes.yaml:$PROCESS"

    echo "Generation of $PROCESS done"
done

echo "All generations done :)"
echo ""

cd ../fcc_pipeline/cli_pipeline

echo "Running configs..."
bash scripts/run_configs.sh

echo "Done :)"