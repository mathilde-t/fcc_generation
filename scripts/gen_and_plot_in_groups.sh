#!/bin/bash

set -e

groups=(
    # "ee_ee ee_mumu"
    "ee_ee_add ee_mumu_add"
    "ee_ee_def ee_mumu_def"
)

cd ../fcc_generation

for GROUP in "${groups[@]}"; do

    echo "========================================"
    echo "Generating group: $GROUP"
    echo "========================================"

    # Generate both processes belonging to this group
    for PROCESS in $GROUP; do

        echo "----------------------------------------"
        echo "Generating process: $PROCESS"
        echo "----------------------------------------"

        bash ./scripts/generation.sh "scripts/processes.yaml:$PROCESS"

        echo "Generation of $PROCESS done"
    done

    echo ""
    echo "All generations for $GROUP done :)"
    echo ""

    cd ../fcc_pipeline/cli_pipeline

    echo "Running configs..."
    bash scripts/run_configs.sh

    echo "Plotting done."
    echo ""

    # Build output name: ee_ee... / ee_mumu... -> ee_ll...
    FIRST_PROCESS="${GROUP%% *}"
    SUFFIX="${FIRST_PROCESS#ee_ee}"

    GROUP_NAME="ee_ll${SUFFIX}"

    echo "Moving plots to output/$GROUP_NAME/"

    mkdir -p "output/$GROUP_NAME"

    mv output/plots_ak "output/$GROUP_NAME/"
    mv output/plots_root "output/$GROUP_NAME/"

    echo "Plots stored in output/$GROUP_NAME/"
    echo ""

    cd ../../fcc_generation

done

echo "========================================"
echo "Everything done :)"
echo "========================================"