#!/bin/bash
set -eo pipefail

# ============================================================
# What :
#    This script generates FCC-ee Monte Carlo events using MadGraph5_aMC@NLO
#    for the hard process and Pythia8 (via k4run) for decays, ISR and FSR.
#   
# Pipeline :
#             1. Hard scattering (matrix element calculation) with MadGraph5_aMC@NLO
#             2. Z decay, initial state radiation (ISR), and FSR with Pythia8
#             3. Conversion to EDM4hep format via k4run
#
# Output : .root file in the EDM4hep format (.e4h.root)
#
# How to run : 
#             1. make sure the environment is set up : 
#                source /cvmfs/sw.hsf.org/key4hep/setup.sh
#             2. run bash generation.sh
#
# ============================================================


### Configuration
PROCESS="ee_z_ll"
PROCESS_DIR="z_prod"

NEVENTS=5000
EBEAM=45.6

OUTPUT_TAG="${PROCESS}_ecm$(printf "%.0f" "$(echo "$EBEAM * 2" | bc)")"
MG_CARD="cards/${OUTPUT_TAG}__mg5.dat"
PYTHIA_CARD="cards/${OUTPUT_TAG}__p8.cmd"

LHE_DIR="lhe"
LOG_DIR="logs"
OUTPUT_DIR="output"

LHE_FILE="${PROCESS_DIR}/Events/run_01/unweighted_events.lhe.gz"

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


# --- Step 2 : Simulate the hard scattering with MadGraph5_aMC@NLO (standalone gener.) ---
echo "--> Checking MadGraph installation"
#echo "should give approx. /cvmfs/sw.hsf.org/spackages7/madgraph5amc/2.8.1/x86_64-centos7-gcc11.2.0-opt/nlauf/bin/mg5_aMC"
which mg5_aMC

echo "--> Running MadGraph"

MG_TMP="${LOG_DIR}/mg5_run.cmd"

cp "${MG_CARD}" "${MG_TMP}"

cat >> "${MG_TMP}" <<EOF

output ${PROCESS_DIR} -f
launch

set nevents ${NEVENTS}
set ebeam1 ${EBEAM}
set ebeam2 ${EBEAM}

done
EOF

# --- Step 3 : save MG output (outcoing particles and infos) as .lhe file ---
LHE_COPY="${LHE_DIR}/${OUTPUT_TAG}.lhe"
cp "${LHE_FILE}" "${LHE_COPY}"


# --- Step 4 : Showering, ISR, and FSR with Pythia8 (FCC k4run), create card ---
echo "--> Checking k4run installation"
#echo "should give approx. /cvmfs/sw.hsf.org/key4hep/releases/2025-05-29/x86_64-almalinux9-gcc14.2.0-opt/k4fwcore/1.3-lix236/bin/k4run"
export OUTPUT_FILE
which k4run

echo "--> Running Pythia"

k4run config/pythia.py \
    -n ${NEVENTS} \
    --Pythia8.PythiaInterface.pythiacard ${PYTHIA_CARD} \
    > ${LOG_DIR}/pythia.log 2>&1


# --- Step 5 : Detector simulation with Delphes (FCC k4run) ---
echo "--> Running detector simulation (Delphes + Pythia)"

DelphesPythia8_EDM4HEP \
    config/card_IDEA.tcl \
    config/edm4hep_IDEA.tcl \
    "${PYTHIA_CARD}" \
    "${DELPHES_OUTPUT}" \
    > "${LOG_DIR}/delphes.log" 2>&1


echo "--> Event generation done :)"
echo "Output file generator level : ${OUTPUT_FILE}"
echo "Output file detector level : ${DELPHES_OUTPUT}"