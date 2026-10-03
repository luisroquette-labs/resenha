#!/bin/zsh
set -euo pipefail

project_root=${0:A:h:h}
source_root="$project_root/Vendor/whisper.cpp"
build_root="$project_root/build/whisper-framework"
cmake_root="$build_root/cmake"
framework_root="$build_root/whisper.framework"
output_root="$project_root/Frameworks/whisper.xcframework"

test -f "$source_root/include/whisper.h" || {
  print -u2 "whisper.cpp submodule is missing; run git submodule update --init"
  exit 1
}

cmake -S "$source_root" -B "$cmake_root" -G Xcode \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
  -DBUILD_SHARED_LIBS=OFF \
  -DWHISPER_BUILD_EXAMPLES=OFF \
  -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_SERVER=OFF \
  -DGGML_METAL=ON \
  -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_BLAS_DEFAULT=ON \
  -DGGML_NATIVE=OFF \
  -DGGML_OPENMP=OFF \
  -DWHISPER_COREML=OFF

cmake --build "$cmake_root" --config Release --target whisper -j 4

libraries=(
  "$cmake_root/src/Release/libwhisper.a"
  "$cmake_root/ggml/src/Release/libggml.a"
  "$cmake_root/ggml/src/Release/libggml-base.a"
  "$cmake_root/ggml/src/Release/libggml-cpu.a"
  "$cmake_root/ggml/src/ggml-metal/Release/libggml-metal.a"
  "$cmake_root/ggml/src/ggml-blas/Release/libggml-blas.a"
)
for library in "${libraries[@]}"; do
  test -f "$library" || {
    print -u2 "missing whisper.cpp library: $library"
    exit 1
  }
done

rm -rf "$framework_root" "$output_root"
mkdir -p "$framework_root/Versions/A/Headers" "$framework_root/Versions/A/Modules" "$framework_root/Versions/A/Resources"
libtool -static -o "$framework_root/Versions/A/whisper" "${libraries[@]}"
cp "$source_root/include/whisper.h" "$framework_root/Versions/A/Headers/"
cp "$source_root/ggml/include/"*.h "$framework_root/Versions/A/Headers/"

cat > "$framework_root/Versions/A/Modules/module.modulemap" <<'MODULEMAP'
framework module whisper {
  umbrella header "whisper.h"
  export *
  module * { export * }
}
MODULEMAP

cat > "$framework_root/Versions/A/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleExecutable</key><string>whisper</string>
<key>CFBundleIdentifier</key><string>org.ggml.whisper</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleName</key><string>whisper</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleShortVersionString</key><string>1.8.2</string>
<key>CFBundleVersion</key><string>1</string>
<key>MinimumOSVersion</key><string>14.0</string>
</dict></plist>
PLIST

ln -s A "$framework_root/Versions/Current"
ln -s Versions/Current/Headers "$framework_root/Headers"
ln -s Versions/Current/Modules "$framework_root/Modules"
ln -s Versions/Current/Resources "$framework_root/Resources"
ln -s Versions/Current/whisper "$framework_root/whisper"

mkdir -p "${output_root:h}"
xcodebuild -create-xcframework -framework "$framework_root" -output "$output_root"
print "Created $output_root"
