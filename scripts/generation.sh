#!/bin/bash
set -eo pipefail

# ============================================================
# What :
#    This script generates FCC-ee Monte Carlo events using MadGraph5_aMC@NLO
#    for the hard process and Pythia8 (via k4run) for decays, ISR and FSR.
#    It is config-driven, with all parameters specified in 'scripts/processes.yaml'
#   
# Pipeline :
#             1. Hard scattering (matrix element calculation) with MadGraph5_aMC@NLO
#             2. Z decay, initial state radiation (ISR), and FSR with Pythia8
#             3. Conversion to EDM4hep format via k4run
#
# Output : .root file in the EDM4hep format (.e4h.root)
#
# How to run : e.g ee_z_ll_ecm91
#             1. make sure the environment is set up : 
#                source /cvmfs/sw.hsf.org/key4hep/setup.sh
#             2. make sure to have the pythia card 'ee_z_ll_ecm91__p8.cmd' in 'cards/'
#             3.1 sinlge run : 'bash scripts/generation.sh scripts/processes.yaml:ee_z_ll'
#             3.2 multiple runs : 'for p in ee_ee ee_mumu ee_z_ee ee_z_mumu; do
#                                   bash scripts/generation.sh scripts/processes.yaml:$p
#                                   done'
#
#             4. merge runs with 'hadd' if needed :
#                 hadd output/merged_ee_mumu.e4h.root output/ee_z_{ee,mumu}_ecm91.e4h.root
#                 hadd output/merged_ee_mumu_delphes.root output/ee_z_{ee,mumu}_ecm91_delphes.root
#
# Results : MG5 to be found in '<process_dir>/HTML/run_01/results.html'
#
# ============================================================

# ---  load process configuration ---
CONFIG_FILE=$1

if [ -z "$CONFIG_FILE" ]; then
    echo "Usage: bash generation.sh configs/processes.yaml:process_name"
    echo "Example: bash generation.sh configs/processes.yaml:ee_z_ll"
    exit 1
fi

# Split input (file:process)
YAML_FILE=$(echo "$CONFIG_FILE" | cut -d: -f1)
PROCESS=$(echo "$CONFIG_FILE" | cut -d: -f2)

echo "--> Using config: $YAML_FILE"
echo "--> Process: $PROCESS"

# ---  Extract configuration ---
EBEAM=$(python3 -c "import yaml; print(yaml.safe_load(open('$YAML_FILE'))['$PROCESS']['ebeam'])")
NEVENTS=$(python3 -c "import yaml; print(yaml.safe_load(open('$YAML_FILE'))['$PROCESS']['nevents'])")
PROCESS_DIR=$(python3 -c "import yaml; print(yaml.safe_load(open('$YAML_FILE'))['$PROCESS']['process_dir'])")
OUTPUT_TAG=$(python3 -c "import yaml; print(yaml.safe_load(open('$YAML_FILE'))['$PROCESS']['output_tag'])")

MG_MODEL=$(python3 -c "import yaml; print(yaml.safe_load(open('$YAML_FILE'))['$PROCESS']['mg5']['model'])")
MG_PROCESS=$(python3 -c "import yaml; print(yaml.safe_load(open('$YAML_FILE'))['$PROCESS']['mg5']['process'])")

LHE_NAME=$(python3 -c "import yaml; print(yaml.safe_load(open('$YAML_FILE'))['$PROCESS']['pythia']['lhe_file'])")

# ---  make directories dynamically ---
MG_CARD="cards/${OUTPUT_TAG}__mg5.dat"
PYTHIA_CARD="cards/${OUTPUT_TAG}__p8.cmd"

LHE_DIR="lhe"
LOG_DIR="logs"
OUTPUT_DIR="output"

LHE_FILE="${PROCESS_DIR}/Events/run_01/unweighted_events.lhe.gz"
LHE_COPY="${LHE_DIR}/${LHE_NAME%.gz}"

OUTPUT_FILE="${OUTPUT_DIR}/${OUTPUT_TAG}.e4h.root"
DELPHES_OUTPUT="${OUTPUT_DIR}/${OUTPUT_TAG}_delphes.root"

mkdir -p cards config "${LHE_DIR}" "${LOG_DIR}" "${OUTPUT_DIR}"

# --- Step 1 : Download steering files if not existing ---
declare -A STEERING_FILES=(
  ["config/pythia.py"]="https://raw.githubusercontent.com/HEP-FCC/k4Gen/main/k4Gen/options/pythia.py"
  ["config/card_IDEA.tcl"]="https://raw.githubusercontent.com/HEP-FCC/FCC-config/winter2023/FCCee/Delphes/card_IDEA.tcl"
  ["config/edm4hep_IDEA.tcl"]="https://raw.githubusercontent.com/HEP-FCC/FCC-config/winter2023/FCCee/Delphes/edm4hep_IDEA.tcl"
)

for f in "${!STEERING_FILES[@]}"; do
    if [ ! -f "$f" ]; then
        echo "--> Downloading $f"
        wget -O "$f" "${STEERING_FILES[$f]}"
    fi
done

# ---  Step 2 : Simulate the hard scattering with MadGraph5_aMC@NLO (standalone gener.) ---
echo "--> Checking MadGraph installation"
#echo "should give approx. /cvmfs/sw.hsf.org/spackages7/madgraph5amc/2.8.1/x86_64-centos7-gcc11.2.0-opt/nlauf/bin/mg5_aMC"
which mg5_aMC

echo "--> Running MadGraph"
echo "PROCESS_DIR = ${PROCESS_DIR}"
MG_PROCESS=$(echo "$MG_PROCESS" | tr '|' '\n')
echo "MG_PROCESS = ${MG_PROCESS}"

if [ -z "$PROCESS_DIR" ]; then
    echo "FATAL: PROCESS_DIR is empty"
    exit 1
fi
rm -rf "${PROCESS_DIR:?}"

cat > "${MG_CARD}" <<EOF
import model ${MG_MODEL}
${MG_PROCESS}
output ${PROCESS_DIR} -f
launch
set nevents ${NEVENTS}
set ebeam1 ${EBEAM}
set ebeam2 ${EBEAM}
done
EOF

mg5_aMC "${MG_CARD}"

# ---  Step 3 : save MG output (outcoing particles and infos) as .lhe file ---
echo "--> Preparing LHE file"

#if [ ! -f "$LHE_FILE" ]; then
LHE_FILE=$(find "${PROCESS_DIR}" -name "unweighted_events.lhe.gz" | head -n 1)

if [ -z "$LHE_FILE" ]; then
    echo "ERROR: no LHE file found in ${PROCESS_DIR}"
    find "${PROCESS_DIR}" -type f | head -100
    exit 1
fi

cp "$LHE_FILE" "${LHE_DIR}/${LHE_NAME}.gz"
gunzip -f "${LHE_DIR}/${LHE_NAME}.gz"
echo "--> LHE file : ${LHE_FILE}"

# ---  Step 4 : Showering, ISR, and FSR with Pythia8 (FCC k4run), create card ---
echo "--> Checking k4run installation"
#echo "should give approx. /cvmfs/sw.hsf.org/key4hep/releases/2025-05-29/x86_64-almalinux9-gcc14.2.0-opt/k4fwcore/1.3-lix236/bin/k4run"
export OUTPUT_FILE
which k4run

echo "--> Running Pythia"

if [ ! -f "${PYTHIA_CARD}" ]; then
    echo "--> No dedicated Pythia card found"
    echo "--> Creating ${PYTHIA_CARD} from template"

    cp cards/template_p8.cmd "${PYTHIA_CARD}"

    sed -i "s|Beams:LHEF = .*|Beams:LHEF = lhe/${LHE_NAME}|" "${PYTHIA_CARD}"
fi

k4run config/pythia.py \
    -n ${NEVENTS} \
    --Pythia8.PythiaInterface.pythiacard ${PYTHIA_CARD} \
    > ${LOG_DIR}/pythia.log 2>&1

mv output_pythia.root "${OUTPUT_FILE}"

# ---  Step 5 : detector simulation with Delphes (FCC k4run) ---
echo "--> Running detector simulation (Delphes + Pythia)"

DelphesPythia8_EDM4HEP \
    config/card_IDEA.tcl \
    config/edm4hep_IDEA.tcl \
    "${PYTHIA_CARD}" \
    "${DELPHES_OUTPUT}" \
    > "${LOG_DIR}/delphes.log" 2>&1


echo "--> Event generation done :)"
echo "Output: ${OUTPUT_FILE}"
echo "Delphes: ${DELPHES_OUTPUT}"