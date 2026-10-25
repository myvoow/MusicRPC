#!/bin/sh
set -eu
cd "$(dirname "$0")"

for arch in arm64 x86_64; do swift build -c release --triple $arch-apple-macosx26.0; done
APP=MusicRPC.app
RES=$APP/Contents/Resources
V=Vendor/mediaremote-adapter

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$RES/MediaRemoteAdapter.framework"
lipo -create .build/arm64-apple-macosx/release/MusicRPC .build/x86_64-apple-macosx/release/MusicRPC -output "$APP/Contents/MacOS/MusicRPC"
cp Info.plist "$APP/Contents/"
cp "$V/bin/mediaremote-adapter.pl" "$RES/"

clang -dynamiclib -fobjc-arc -fvisibility=default -arch x86_64 -arch arm64 -mmacosx-version-min=11.0 -w \
  -I"$V/include" -I"$V/src" "$V"/src/adapter/*.m "$V"/src/private/*.m "$V"/src/utility/*.m \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  -install_name @rpath/MediaRemoteAdapter.framework/MediaRemoteAdapter \
  -o "$RES/MediaRemoteAdapter.framework/MediaRemoteAdapter"

codesign --force -s - "$RES/MediaRemoteAdapter.framework/MediaRemoteAdapter"
codesign --force -s - "$APP"
echo "Built $APP"
