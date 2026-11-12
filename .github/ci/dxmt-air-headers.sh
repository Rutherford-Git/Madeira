#!/usr/bin/env bash
# airconv_context.cpp includes air_msad.h, air_samplepos.h and
# air_tessellation.h, which DXMT's meson build generates (metal -> .air ->
# xxd, dxmt/src/airconv/meson.build) and build/dxmt-ios/build.sh does not.
# Same chain and arguments, into the shader-headers folder that script reads.
set -euo pipefail

R="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="$R/build/dxmt-ios/shader-headers"
mkdir -p "$OUT"
cd "$OUT"
for name in air_msad air_samplepos air_tessellation; do
    xcrun -sdk macosx metal -std=metal3.1 --target=air64-apple-macos14.0 \
        -o "$name.air" -c "$R/dxmt/src/airconv/shaders/$name.metal"
    xxd -n "$name" -i "$name.air" "$name.h"
    echo "$name.h: $(wc -c < "$name.h" | tr -d ' ') bytes"
done
