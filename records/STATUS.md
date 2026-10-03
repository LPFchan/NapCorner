# NapCorner Status

This document tracks current operational truth.
Update it when the project's real state changes.

## Snapshot

- Last updated: 2026-10-03
- Overall posture: `active`
- Current focus: v0.1.1 is out (public repo, DMG, Sparkle feed,
  napcorner.lost.plus, 29 UI languages); next is feedback from real use
- Highest-priority blocker: none
- Next operator decision needed: none
- Related decisions: none yet

## Current State Summary

The app works end to end on the operator's Mac: hold or push to sleep, the
pill indicator, the haptic tap, and re-sleeping when the mouse wakes the
display during the guard window. Onboarding, settings, launch at login and
Sparkle are in place, v0.1.0 shipped on 2026-10-02, and v0.1.1
(a longer wake guard, counted from the screen going dark) on 2026-10-03. Debug builds have a Spring Tuner window for adjusting
the indicator's springs live.
