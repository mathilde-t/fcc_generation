# Beam ISR in the local generation

`scripts/processes.yaml` processes can set `mg5: isr: true` (used by `ee_ee_isr`, `ee_mumu_isr`).
`scripts/generation.sh` then generates with the MG5 LL electron ISR structure function
(`lpp1 = 3`, `lpp2 = -3`, `pdlabel = isronlyll`; incoming `e- e+` in this order) and runs Pythia8 with
`PDF:lepton = on`, `PartonLevel:ISR = off` (ISR already in the LHE events, no double counting).
Without the flag nothing changes.

Before, `PDF:lepton = off` + Born-level LHE meant the local samples had no beam ISR at all.

Motivation, validation, cross sections and the local vs central results:
`fcc_pipeline/ISR_FIDUCIAL_README.md` (branch `feature/isr-fiducial`).

```bash
source /cvmfs/sw.hsf.org/key4hep/setup.sh
for p in ee_ee_isr ee_mumu_isr; do bash scripts/generation.sh scripts/processes.yaml:$p; done   # sequentially
```
