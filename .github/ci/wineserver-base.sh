#!/usr/bin/env bash
# build/wineserver/build.sh swaps its patched objects into an existing
# libwineserver.a, which is not in the repository. This makes that base
# archive: every wine/server/*.c compiled with the flags that script uses
# (keep CC_FLAGS in step with it), in build/wineserver/obj/libwineserver.a.
set -euo pipefail

R="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="$R/build/wineserver"
WINE_SRC="$R/wine"
SHIMS_DIR="$R/build/ntdll-unix/shims"
SDK=$(xcrun --sdk iphoneos --show-sdk-path)
OBJ_DIR="$BUILD_DIR/obj/base"

CC_FLAGS=(
    -arch arm64 -isysroot "$SDK" -miphoneos-version-min=17.0 -O2
    -I"$WINE_SRC/include" -I"$WINE_SRC/include/wine"
    -I"$WINE_SRC/build-macos/include"
    -I"$BUILD_DIR" -I"$WINE_SRC/server"
    -I"$SHIMS_DIR"
    -I"$BUILD_DIR/../madsync" -DHAVE_LINUX_NTSYNC_H=1
    -include "$BUILD_DIR/config_ios.h"
    -include stdarg.h
    -include "$BUILD_DIR/unicode_fix.h"
    -include "$BUILD_DIR/wineserver_ios_kill.h"
    -DBINDIR=\"/usr/local/bin\" -DDATADIR=\"/usr/local/share\"
    -D__WINESRC__ -DWINE_IOS=1
    -Dmain=wineserver_main
    -Wno-implicit-function-declaration
)

mkdir -p "$OBJ_DIR"
failed=()
for src in "$WINE_SRC"/server/*.c; do
    name=$(basename "$src" .c)
    if ! xcrun -sdk iphoneos clang "${CC_FLAGS[@]}" -c "$src" -o "$OBJ_DIR/$name.o" 2>"$OBJ_DIR/$name.err"; then
        failed+=("$name")
        rm -f "$OBJ_DIR/$name.o"
    fi
done
for name in ${failed[@]+"${failed[@]}"}; do
    echo "::warning::wineserver base: $name.c did not compile"
    head -5 "$OBJ_DIR/$name.err"
done
rm -f "$BUILD_DIR/obj/libwineserver.a"
xcrun -sdk iphoneos ar rcs "$BUILD_DIR/obj/libwineserver.a" "$OBJ_DIR"/*.o
echo "base libwineserver.a: $(ls "$OBJ_DIR"/*.o | wc -l | tr -d ' ') objects, ${#failed[@]} failed"
