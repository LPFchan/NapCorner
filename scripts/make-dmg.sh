#!/bin/sh
# Packs build/NapCorner.app into build/NapCorner.dmg with DMGMaker
# (https://github.com/saihgupr/DMGMaker, pinned) and our background.
# Packaging/DMGMaker-v1.0.3.patch adds the --background option, as in Markfops.
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
tool="$root/build/dmgtool"
if [ ! -d "$tool" ]; then
    git clone -q --depth 1 --branch v1.0.3 https://github.com/saihgupr/DMGMaker "$tool" 2>/dev/null
    git -C "$tool" apply --unidiff-zero "$root/Packaging/DMGMaker-v1.0.3.patch"
fi
rm -f "$root/build/NapCorner.dmg"
(cd "$tool" && swift run -c release "DMG Maker" --app "$root/build/NapCorner.app" --name NapCorner \
    --background "$root/Packaging/DMGBackground.png")
test -f "$root/build/NapCorner.dmg"
echo "$root/build/NapCorner.dmg"
