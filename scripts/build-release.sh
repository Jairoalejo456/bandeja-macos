#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
derived_data="$project_root/.build/Release"
output_directory="$project_root/dist"
app_source="$derived_data/Build/Products/Release/Bandeja.app"
app_destination="$output_directory/Bandeja.app"
staging_directory=$(/usr/bin/mktemp -d /tmp/BandejaRelease.XXXXXX)
staged_app="$staging_directory/Bandeja.app"

cleanup() {
  rm -rf "$staging_directory"
}
trap cleanup EXIT

mkdir -p "$output_directory"

xcodebuild \
  -project "$project_root/Bandeja.xcodeproj" \
  -scheme Bandeja \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

ditto "$app_source" "$staged_app"
xattr -cr "$staged_app"
codesign --force --deep --sign - "$staged_app"
codesign --verify --deep --strict "$staged_app"

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$staged_app/Contents/Info.plist")
archive="$output_directory/Bandeja-$version-macOS-universal.zip"
staged_archive="$staging_directory/Bandeja-$version-macOS-universal.zip"
ditto -c -k --keepParent "$staged_app" "$staged_archive"
ditto "$staged_app" "$app_destination"
ditto "$staged_archive" "$archive"

echo "Creado: $archive"
lipo -archs "$staged_app/Contents/MacOS/Bandeja"
