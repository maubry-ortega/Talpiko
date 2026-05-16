#!/bin/bash
set -e

# Pikpo WASM Build Script
# Compiles Nim to WASM using Clang

SRC="build/frontend/app.nim"
OUT="build/frontend/app.wasm"
NIM_CACHE="nimcache/wasm"

mkdir -p $NIM_CACHE
mkdir -p build/frontend

echo "--- Compiling Nim to C (WASM target) ---"
nim c --compileOnly --noMain --os:Standalone --cpu:wasm32 --mm:arc \
      --panics:on --define:nimNoLibc --define:useMalloc --define:wasm \
      --define:danger --nimcache:$NIM_CACHE \
      --path:src/talpiko/backend \
      --path:src/talpiko/frontend \
      --path:src \
      $SRC

echo "--- Linking C to WASM via Clang ---"
# Collect all generated .c files
C_FILES=$(find $NIM_CACHE -name "*.c")
MALLOC_C="src/talpiko/frontend/wasm_malloc.c"

clang --target=wasm32 -nostdlib -Wl,--no-entry -Wl,--export-all \
      -Wl,--allow-undefined \
      -o $OUT $C_FILES $MALLOC_C \
      -I/home/DevMaubry/.choosenim/toolchains/nim-2.2.4/lib \
      -Isrc/talpiko/frontend \
      -Ibuild/frontend/include

echo "--- WASM Build Complete: $OUT ---"
ls -lh $OUT
