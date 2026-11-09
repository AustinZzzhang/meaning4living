#!/bin/bash
# Build the native app from this checkout. Optional --universal adds Intel; prints the app path on success.
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$project_dir/.build/direct"
dist_dir="$project_dir/dist"
app_path="$dist_dir/活着的意义.app"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
host_arch="$(uname -m)"
architectures=("$host_arch")
if [[ "${1:-}" == "--universal" ]]; then
    architectures=(arm64 x86_64)
elif [[ -n "${1:-}" ]]; then
    printf 'Usage: bash scripts/build.sh [--universal]\n' >&2
    exit 2
fi
mkdir -p "$build_dir" "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
sparkle_dir="$(python3 "$project_dir/scripts/fetch-sparkle.py")"
overlay="$(python3 "$project_dir/scripts/prepare-toolchain.py" "$build_dir/toolchain")"
compiler_flags=(-sdk "$sdk_path" -swift-version 5 -vfsoverlay "$overlay" -Xcc -ivfsoverlay -Xcc "$overlay")
binaries=()
for architecture in "${architectures[@]}"; do
    architecture_dir="$build_dir/$architecture"
    mkdir -p "$architecture_dir"
    printf 'Building %s…\n' "$architecture"
    xcrun swiftc "${compiler_flags[@]}" -target "$architecture-apple-macosx13.0" \
        -O -whole-module-optimization -parse-as-library -emit-module -emit-object \
        -module-name LivingCore "$project_dir"/Sources/LivingCore/*.swift \
        -emit-module-path "$architecture_dir/LivingCore.swiftmodule" -o "$architecture_dir/LivingCore.o"
    xcrun swiftc "${compiler_flags[@]}" -target "$architecture-apple-macosx13.0" \
        -O -whole-module-optimization -module-name LivingMeaning -I "$architecture_dir" \
        -F "$sparkle_dir" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
        "$project_dir"/Sources/LivingMeaning/*.swift "$architecture_dir/LivingCore.o" \
        -o "$architecture_dir/LivingMeaning"
    binaries+=("$architecture_dir/LivingMeaning")
done
if [[ "${#binaries[@]}" -gt 1 ]]; then
    lipo -create "${binaries[@]}" -output "$app_path/Contents/MacOS/LivingMeaning"
else
    cp "${binaries[0]}" "$app_path/Contents/MacOS/LivingMeaning"
fi
cp "$project_dir/Resources/Info.plist" "$app_path/Contents/Info.plist"
configured_feed="$(python3 "$project_dir/scripts/github-release.py" feed-url)"
release_feed="${LIVING_UPDATE_FEED_URL:-$configured_feed}"
if [[ -n "$release_feed" ]]; then
    /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $release_feed" "$app_path/Contents/Info.plist"
fi
mkdir -p "$app_path/Contents/Frameworks"
ditto "$sparkle_dir/Sparkle.framework" "$app_path/Contents/Frameworks/Sparkle.framework"
cp "$sparkle_dir/LICENSE" "$app_path/Contents/Resources/Sparkle-LICENSE.txt"
printf 'APPL????' > "$app_path/Contents/PkgInfo"

xcrun swiftc "${compiler_flags[@]}" "$project_dir/scripts/GenerateIcon.swift" -o "$build_dir/generate-icon"
"$build_dir/generate-icon" "$project_dir/Resources/AppIconSource.png" "$build_dir/icon.png"
iconset="$build_dir/AppIcon.iconset"
mkdir -p "$iconset"
for pixels in 16 32 128 256 512; do
    sips -z "$pixels" "$pixels" "$build_dir/icon.png" --out "$iconset/icon_${pixels}x${pixels}.png" >/dev/null
    doubled=$((pixels * 2))
    sips -z "$doubled" "$doubled" "$build_dir/icon.png" \
        --out "$iconset/icon_${pixels}x${pixels}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o "$app_path/Contents/Resources/AppIcon.icns"
python3 "$project_dir/scripts/build-info.py" write "$app_path"
signing_identity="${LIVING_SIGNING_IDENTITY:--}"
python3 "$project_dir/scripts/sign-app.py" "$app_path" --identity "$signing_identity"
codesign --verify --deep --strict "$app_path"
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$dist_dir/活着的意义-mac.zip"
printf 'Built: %s\n' "$app_path"
