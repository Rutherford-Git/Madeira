#!/usr/bin/env bash
# Builds the LLVM-for-iOS archives DXMT's AIR compiler links, following the
# recipe in docs/BUILDING.md ("Inputs that are not in the repository"): a host
# llvm-tblgen in toolchains/llvm-host-build, then the iOS libraries in
# toolchains/llvm-ios-build. Only what build/dxmt-ios/build.sh reads is kept
# (lib/*.a, the generated include/ and the source include/), so the CI cache
# stays small. Does nothing when those are already there.
set -euo pipefail

R="$(cd "$(dirname "$0")/../.." && pwd)"
T="$R/toolchains"
SRC="$T/llvm-project"
HOST="$T/llvm-host-build"
IOS="$T/llvm-ios-build"
LLVM_COMMIT=8dfdcc7b7bf66834a761bd8de445840ef68e4d1a
JOBS=$(sysctl -n hw.ncpu)

# The libraries dxmt/src/airconv/meson.build links (llvm-config --libs bitwriter passes).
LIBS=(LLVMPasses LLVMTarget LLVMObjCARCOpts LLVMCoroutines LLVMipo LLVMInstrumentation
      LLVMVectorize LLVMLinker LLVMIRReader LLVMAsmParser LLVMFrontendOpenMP LLVMScalarOpts
      LLVMInstCombine LLVMAggressiveInstCombine LLVMTransformUtils LLVMBitWriter LLVMAnalysis
      LLVMProfileData LLVMSymbolize LLVMDebugInfoPDB LLVMDebugInfoMSF LLVMDebugInfoDWARF
      LLVMObject LLVMTextAPI LLVMMCParser LLVMMC LLVMDebugInfoCodeView LLVMBitReader LLVMCore
      LLVMRemarks LLVMBitstreamReader LLVMBinaryFormat LLVMSupport LLVMDemangle)

if [ -f "$IOS/lib/libLLVMCore.a" ] && [ -f "$IOS/include/llvm/Config/llvm-config.h" ] \
   && [ -d "$SRC/llvm/include/llvm" ]; then
    echo "LLVM for iOS already built"
    exit 0
fi

COMMON=(-G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5
        -DLLVM_TARGETS_TO_BUILD= -DLLVM_ENABLE_PROJECTS= -DLLVM_INCLUDE_TESTS=OFF
        -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF -DLLVM_ENABLE_ZLIB=OFF
        -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_TERMINFO=OFF)

mkdir -p "$T"
if [ ! -d "$SRC/llvm" ]; then
    rm -rf "$SRC"
    git init -q "$SRC"
    git -C "$SRC" fetch -q --depth 1 --filter=blob:none https://github.com/llvm/llvm-project.git "$LLVM_COMMIT"
    git -C "$SRC" sparse-checkout set --no-cone /llvm /cmake /third-party
    git -C "$SRC" checkout -q FETCH_HEAD
fi

echo "=== host llvm-tblgen ==="
cmake -S "$SRC/llvm" -B "$HOST" "${COMMON[@]}"
ninja -C "$HOST" -j"$JOBS" llvm-tblgen

echo "=== iOS libraries ==="
cmake -S "$SRC/llvm" -B "$IOS" "${COMMON[@]}" \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_SYSROOT=iphoneos \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 -DCMAKE_MACOSX_BUNDLE=OFF \
    -DLLVM_HOST_TRIPLE=arm64-apple-ios17.0 -DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-ios17.0 \
    -DLLVM_TARGET_ARCH=host -DLLVM_BUILD_TOOLS=OFF -DLLVM_INCLUDE_UTILS=OFF \
    -DLLVM_TABLEGEN="$HOST/bin/llvm-tblgen"
ninja -C "$IOS" -j"$JOBS" "${LIBS[@]}"

# Keep what the DXMT build reads; drop the object trees.
find "$IOS" -mindepth 1 -maxdepth 1 ! -name lib ! -name include -exec rm -rf {} +
find "$IOS/lib" -mindepth 1 ! -name '*.a' -exec rm -rf {} + 2>/dev/null || true
rm -rf "$HOST"
ls "$IOS/lib"
