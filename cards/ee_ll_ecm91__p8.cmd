! main03.cmnd.
! This file contains commands to be read in for a Pythia8 run.
! Lines not beginning with a letter or digit are comments.
! Names are case-insensitive  -  but spellings-sensitive!

! ==========================================================
! Settings used in the main program
! ==========================================================

Random:setSeed = on
Random:seed = 12345
Main:timesAllowErrors = 5          ! how many aborts before run stops
Stat:showProcessLevel = on

! ==========================================================
! Settings related to output in init(), next() and stat()
! ==========================================================

Init:showChangedSettings = on      ! list changed settings
Init:showChangedParticleData = off ! list changed particle data
Next:numberCount = 100             ! print message every n events
Next:numberShowInfo = 1            ! print event information n times
Next:numberShowProcess = 1         ! print process record n times
Next:numberShowEvent = 0           ! print event record n times

! ==========================================================
! Read LHE events from MadGraph
! ==========================================================

Beams:frameType = 4
Beams:LHEF = lhe/ee_ll_ecm91.lhe

! ==========================================================
! ISR and FSR
! ==========================================================

PDF:lepton = off
! SpaceShower:QEDshowerByL = on
PartonLevel:ISR = on
PartonLevel:FSR = on

! ==========================================================
! Z decays to ee and mumu in MadGraph, so turn off in Pythia
! ==========================================================

! turn off all decays of Z
23:onMode = off
! 23:onIfMatch = 11 -11
! 23:onIfMatch = 13 -13