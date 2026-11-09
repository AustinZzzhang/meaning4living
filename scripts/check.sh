#!/bin/bash
# Build and run deterministic business-rule checks with Command Line Tools; returns nonzero on failure.
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$project_dir/.build/checks"
mkdir -p "$build_dir"
overlay="$(python3 "$project_dir/scripts/prepare-toolchain.py" "$build_dir/toolchain")"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
compiler_flags=(-sdk "$sdk_path" -swift-version 5 -vfsoverlay "$overlay" -Xcc -ivfsoverlay -Xcc "$overlay")
xcrun swiftc "${compiler_flags[@]}" -parse-as-library -whole-module-optimization \
    -emit-module -emit-object -module-name LivingCore "$project_dir"/Sources/LivingCore/*.swift \
    -emit-module-path "$build_dir/LivingCore.swiftmodule" -o "$build_dir/LivingCore.o"
xcrun swiftc "${compiler_flags[@]}" -I "$build_dir" \
    "$project_dir/Sources/LivingMeaningChecks/main.swift" "$build_dir/LivingCore.o" \
    -o "$build_dir/LivingMeaningChecks"
"$build_dir/LivingMeaningChecks"
