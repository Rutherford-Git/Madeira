#!/usr/bin/env bash
# The app links libdxmt_combined.a: build/dxmt-ios/build.sh's libdxmt_unix.a
# merged with the LLVM archives its AIR compiler needs. That script only
# refreshes an existing combined archive, which is not in the repository, so
# this makes it from scratch and stages it in app/Madeira.
set -euo pipefail

R="$(cd "$(dirname "$0")/../.." && pwd)"
UNIX="$R/build/dxmt-ios/libdxmt_unix.a"
OUT="$R/build/dxmt-ios/libdxmt_combined.a"
LLVM_LIB="$R/toolchains/llvm-ios-build/lib"

[ -f "$UNIX" ] || { echo "missing $UNIX; run build/dxmt-ios/build.sh first" >&2; exit 1; }
rm -f "$OUT"
xcrun -sdk iphoneos libtool -static -no_warning_for_no_symbols -o "$OUT" "$UNIX" "$LLVM_LIB"/libLLVM*.a
cp "$OUT" "$R/app/Madeira/libdxmt_combined.a"
echo "app/Madeira/libdxmt_combined.a: $(wc -c < "$OUT" | tr -d ' ') bytes"
