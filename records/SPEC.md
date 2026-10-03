# NapCorner Spec

This file is the canonical statement of what NapCorner is supposed to be.
Keep it durable. Do not use it as a changelog, inbox, or weekly narrative.

- Project: NapCorner
- Canonical repo: LPFchan/NapCorner
- Project id: napcorner
- Operator: yeowool
- Last updated: 2026-10-02
- Related decisions: none yet

## Project thesis

macOS's "Put Display to Sleep" hot corner fires on any brush of the corner,
and the display wakes again on the next twitch of the mouse. NapCorner
replaces it with a corner that asks for intent before sleeping and ignores
the mouse for a moment afterwards.

## Core capabilities

- Watch the pointer with global `NSEvent` monitors (no permissions needed).
  A corner counts only when no other display continues past it.
- Before sleep: the pointer must rest in the corner for the hold time, or push
  into it (pointer deltas while pinned) past the push distance. Pushes in the
  first 0.3 s, and more than 18 pt per event, don't count, so a flick through
  the corner can't sleep the display.
- A black pill springs out of the corner, types "Sleeping … zzzZ" one
  character at a time as a white outline fills, swells, and squashes when
  pushed. All motion is hand-stepped springs (`Nap/Spring.swift`).
- On commit: one trackpad haptic tap, a black curtain closes from the corner,
  then `pmset displaysleepnow`.
- After sleep: during the guard window (0–5 s, default 3 s, counted from the
  displays going dark), a display woken by the mouse is put straight back to
  sleep behind the curtain, including a wake still showing when the window
  ends. A key press or click ends the guard and wakes normally, with no
  animation.
- Offers to turn off the macOS hot corner on the same corner.

## Invariants

- No permission prompts. Everything used works without Accessibility.
- No analytics or telemetry; the only network request is Sparkle's update
  check against `napcorner.lost.plus`.
- `LSUIElement = true` (menu bar app, no dock icon).
- The trackpad haptic uses the private MultitouchSupport actuator (like
  HapticKey), loaded with `dlopen`, and does nothing when unavailable.

## Non-goals

- Other hot-corner actions.
- Putting the whole Mac to sleep (display only).
