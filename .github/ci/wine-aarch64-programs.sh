#!/usr/bin/env bash
# winedevice.exe, svchost.exe and plugplay.exe in app/Madeira/aarch64-windows
# are ignored by git, so a checkout has none of them. Builds them from the
# aarch64 PE half of wine/build-macos (configure-wine.sh) and strips them like
# the other shipped builtins.
set -euo pipefail

R="$(cd "$(dirname "$0")/../.." && pwd)"
TC="$R/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin"
B="$R/wine/build-macos"
DEST="$R/app/Madeira/aarch64-windows"
export PATH="$TC:$PATH"

PROGRAMS=(winedevice svchost plugplay)
targets=()
for p in "${PROGRAMS[@]}"; do targets+=("programs/$p/aarch64-windows/$p.exe"); done
make -C "$B" -j"$(sysctl -n hw.ncpu)" "${targets[@]}"
for p in "${PROGRAMS[@]}"; do
    "$TC/aarch64-w64-mingw32-strip" --strip-debug -o "$DEST/$p.exe" "$B/programs/$p/aarch64-windows/$p.exe"
    echo "$p.exe: $(wc -c < "$DEST/$p.exe" | tr -d ' ') bytes"
done
