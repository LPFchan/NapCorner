# NapCorner

A macOS menu bar app that makes the "Put Display to Sleep" hot corner
deliberate.

**[Download](https://github.com/LPFchan/NapCorner/releases/latest/download/NapCorner.dmg)** · [napcorner.lost.plus](https://napcorner.lost.plus) · macOS 15+, Apple silicon and Intel

---

## What it does

The built-in hot corner sleeps the display the moment the pointer brushes the
corner, and wakes it again on the next twitch of the mouse. NapCorner fixes
both ends:

- **Before sleep**: rest the pointer in the corner for a moment, or push the
  mouse into it. A little pill springs out of the corner and types
  "Sleeping … zzzZ" as its outline fills. Flicking through the corner doesn't
  count.
- **After sleep**: for a short while, bumping the mouse won't wake the display.
  A key press or a click always does.

The hold time, push firmness and how long to ignore the mouse are in
Settings. NapCorner offers to turn off the macOS hot corner on the same
corner so the two don't both fire. It needs no permissions.

## Install

1. Open `NapCorner.dmg` and drag **NapCorner** into **Applications**.
2. Open NapCorner. macOS refuses the first launch because the app isn't notarized by Apple.
3. Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**, then open it again.

NapCorner updates itself with [Sparkle](https://sparkle-project.org).

## Build

Needs Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
sh scripts/build-app.sh   # build/NapCorner.app
sh scripts/make-dmg.sh    # build/NapCorner.dmg
```

`build-app.sh` signs with the "NapCorner Self-Signed" certificate when it's in
the keychain, else ad-hoc. Releases are built by CI when a `v*` tag is pushed.

Launch arguments: `--onboarding` shows the first-launch window again. In debug
builds, `--tune` opens the Spring Tuner and `--preview-indicator` loops the
pill in the top-right corner.

## License

MIT. See [LICENSE](LICENSE).
