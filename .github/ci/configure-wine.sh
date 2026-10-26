#!/usr/bin/env bash
# Configures wine/build-macos, the tree whose config.h and IDL-generated headers
# build/ntdll-unix, build/wineserver and build/win32u-unix compile against.
# docs/BUILDING.md does not record its configure line. This one gives those
# scripts what they read: an aarch64 PE half (llvm-mingw), and GnuTLS and
# FreeType found on the host so config.h defines their sonames (the unix sides
# of bcrypt, secur32, crypt32 and dwrite are compiled out without them).
set -euo pipefail

R="$(cd "$(dirname "$0")/../.." && pwd)"
MINGW="$R/toolchains/llvm-mingw-20260421-ucrt-macos-universal/bin"
B="$R/wine/build-macos"
JOBS=$(sysctl -n hw.ncpu)
export PATH="$MINGW:$PATH"

mkdir -p "$B"
if [ ! -f "$B/config.status" ]; then
    (cd "$B" && ../configure --enable-archs=aarch64 --without-x --disable-tests \
        --enable-winegstreamer) > "$B/configure.out" 2>&1 \
        || { tail -60 "$B/configure.out"; exit 1; }
    tail -25 "$B/configure.out"
fi
make -C "$B" -j"$JOBS" include/all

# build/ntdll-unix reads dwrite's generated headers from the arm64ec tree. They
# are the same IDL output, so point that path at this tree's include/.
mkdir -p "$R/wine/build-arm64ec"
[ -e "$R/wine/build-arm64ec/include" ] || ln -s ../build-macos/include "$R/wine/build-arm64ec/include"

for s in SONAME_LIBGNUTLS SONAME_LIBFREETYPE; do
    grep -q "#define $s " "$B/include/config.h" || { echo "config.h has no $s" >&2; exit 1; }
done
grep -E "#define SONAME_LIB(GNUTLS|FREETYPE) " "$B/include/config.h"
