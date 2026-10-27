#!/usr/bin/env python3
"""
Apply a Gaussian beam energy spread to an LHE file (MG5 has none, central Whizard uses 0.132% per beam).

Per event, both beam energies are drawn from Gauss(E_beam, rel_spread * E_beam) and every particle is
  1. boosted along z into the partonic c.m. frame,
  2. scaled by k = sqrt(E1' E2') / E_beam (massless leptons, so sqrt(s_hat) scales with the beams),
  3. boosted back with the new asymmetry (x1 E1' - x2 E2') / (x1 E1' + x2 E2').
The event weights are kept, i.e. the change of sigma(sqrt(s)) within +-85 MeV is neglected.

The beam energy in <init> is raised to E_beam * (1 + max(nsigma * rel_spread, init_margin)), so that Pythia
(PDF:lepton = on) always finds x < 1; the difference to the drawn beam energy goes into the beam-remnant photon along the beam.
This is needed also without spread (--spread 0): with x = 1 incoming leptons, Pythia showers (almost) no FSR
for events without an s-channel resonance in the record (Bhabha: FSR in 27% instead of 49% of the events).

usage: lhe_beam_spread.py in.lhe out.lhe [--ebeam 45.6] [--spread 0.00132] [--init-margin 0.0066] [--seed 4711] [--nmax N]
"""

import argparse
import math
import random


def boost_z(px, py, pz, e, beta):
    gamma = 1. / math.sqrt(1. - beta * beta)
    return px, py, gamma * (pz + beta * e), gamma * (e + beta * pz)


def transform_event(lines, ebeam, rel_spread, nsigma, rng):
    header = lines[0].split()
    parts = [l.split() for l in lines[1:1 + int(header[0])]]
    rest = lines[1 + int(header[0]):]

    incoming = [p for p in parts if p[1] == "-1"]
    pz_in = sum(float(p[8]) for p in incoming)
    e_in = sum(float(p[9]) for p in incoming)
    beta0 = pz_in / e_in
    x = {int(p[0]): abs(float(p[8])) / ebeam for p in incoming}   # 11: e- (beam 1, +z), -11: e+ (beam 2, -z)

    def draw():
        while True:
            v = rng.gauss(0., 1.)
            if abs(v) < nsigma:
                return ebeam * (1. + rel_spread * v)
    e1, e2 = draw(), draw()
    k = math.sqrt(e1 * e2) / ebeam
    p1, p2 = x[11] * e1, x[-11] * e2
    beta1 = (p1 - p2) / (p1 + p2)

    out = []
    for p in parts:
        px, py, pz, e = (float(v) for v in p[6:10])
        px, py, pz, e = boost_z(px, py, pz, e, -beta0)
        px, py, pz, e = (k * v for v in (px, py, pz, e))
        px, py, pz, e = boost_z(px, py, pz, e, beta1)
        m = k * float(p[10])
        out.append(" ".join(p[:6]) + f" {px:+.10e} {py:+.10e} {pz:+.10e} {e:.10e} {m:.10e} " + " ".join(p[11:]))
    header[3] = f"{k * float(header[3]):.8e}"   # SCALUP
    return [" ".join(header)] + out + rest


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("inp")
    ap.add_argument("out")
    ap.add_argument("--ebeam", type=float, default=45.6)
    ap.add_argument("--spread", type=float, default=0.00132)
    ap.add_argument("--nsigma", type=float, default=5.)
    ap.add_argument("--init-margin", type=float, default=5. * 0.00132)
    ap.add_argument("--seed", type=int, default=4711)
    ap.add_argument("--nmax", type=int, default=-1)
    a = ap.parse_args()
    rng = random.Random(a.seed)
    e_init = a.ebeam * (1. + max(a.nsigma * a.spread, a.init_margin))

    n = 0
    in_init = in_event = False
    with open(a.inp) as fin, open(a.out, "w") as fout:
        for line in fin:
            s = line.strip()
            if s.startswith("<init>"):
                in_init, first = True, True
                fout.write(line)
                continue
            if in_init and first:
                v = line.split()
                v[2], v[3] = f"{e_init:.8e}", f"{e_init:.8e}"
                fout.write(" ".join(v) + "\n")
                first = False
                continue
            if s.startswith("</init>"):
                in_init = False
            if s.startswith("<event"):
                if a.nmax >= 0 and n >= a.nmax:
                    fout.write("</LesHouchesEvents>\n")
                    break
                in_event, buf = True, []
                fout.write(line)
                continue
            if in_event:
                if s.startswith("</event>"):
                    fout.write("\n".join(transform_event(buf, a.ebeam, a.spread, a.nsigma, rng)) + "\n")
                    fout.write(line)
                    in_event = False
                    n += 1
                else:
                    buf.append(line.rstrip("\n"))
                continue
            fout.write(line)
    print(f"{n} events written to {a.out} (spread {a.spread:.4%} per beam, <init> beam energy {e_init:.4f} GeV)")


if __name__ == "__main__":
    main()
