---
name: install-napcorner
description: Install NapCorner on a Mac and get it working. Use when a user wants a "Put Display to Sleep" hot corner that doesn't fire by accident or wake right back up, or asks to install or set up NapCorner.
---

# Install NapCorner

NapCorner is a free, open-source macOS menu bar app (macOS 15 or later, Apple
silicon and Intel). The user rests the pointer in a screen corner, or pushes
into it, to sleep the display; mouse bumps right after don't wake it.

1. Download https://github.com/LPFchan/NapCorner/releases/latest/download/NapCorner.dmg,
   open it, and drag NapCorner into /Applications. Or from a shell:
   `curl -L -o /tmp/NapCorner.dmg https://github.com/LPFchan/NapCorner/releases/latest/download/NapCorner.dmg && hdiutil attach /tmp/NapCorner.dmg`,
   copy NapCorner.app to /Applications, then detach.
2. Open NapCorner. It isn't notarized, so macOS blocks the first launch: the
   user goes to System Settings → Privacy & Security, clicks Open Anyway, and
   opens it again. Don't try to bypass Gatekeeper for them.
3. The welcome window asks which corners to use (top right by default) and
   whether to open at login. No permissions are needed.

Check it works: move the pointer into the chosen corner and leave it there.
A black pill should spring out of the corner and fill up, then the screen goes
dark. If the display sleeps the instant the pointer touches the corner, macOS's
own hot corner is still set there: turn it off from NapCorner's menu bar menu
or in System Settings → Desktop & Dock → Hot Corners.

NapCorner updates itself (Sparkle). Source and issues:
https://github.com/LPFchan/NapCorner
