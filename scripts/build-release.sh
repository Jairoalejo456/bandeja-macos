#!/bin/zsh
set -euo pipefail

project_root="${0:A:h:h}"
derived_data="$project_root/.build/Release"
output_directory="$project_root/dist"
app_source="$derived_data/Build/Products/Release/MiniTray.app"
app_destination="$output_directory/MiniTray.app"
staging_directory=$(/usr/bin/mktemp -d /tmp/MiniTrayRelease.XXXXXX)
staged_app="$staging_directory/MiniTray.app"

cleanup() {
  rm -rf "$staging_directory"
}
trap cleanup EXIT

mkdir -p "$output_directory"

xcodebuild \
  -project "$project_root/MiniTray.xcodeproj" \
  -scheme MiniTray \
  -configuration Release \
  -derivedDataPath "$derived_data" \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build

ditto "$app_source" "$staged_app"
cmp "$project_root/LICENSE" "$staged_app/Contents/Resources/LICENSE"
xattr -cr "$staged_app"
codesign --force --deep --sign - "$staged_app"
codesign --verify --deep --strict "$staged_app"

version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$staged_app/Contents/Info.plist")
archive="$output_directory/MiniTray-$version-macOS-universal.zip"
staged_archive="$staging_directory/MiniTray-$version-macOS-universal.zip"
ditto -c -k --keepParent --norsrc --noextattr --noacl "$staged_app" "$staged_archive"

rm -rf "$app_destination"
rm -f "$archive"
ditto "$staged_app" "$app_destination"
ditto "$staged_archive" "$archive"
xattr -cr "$app_destination"
# Algunos proveedores de archivos vuelven a adjuntar estas marcas al directorio
# raíz inmediatamente después de copiarlo. No forman parte de la aplicación y
# `codesign --strict` las rechaza, así que se retiran de forma explícita.
xattr -d com.apple.FinderInfo "$app_destination" 2>/dev/null || true
xattr -d 'com.apple.fileprovider.fpfs#P' "$app_destination" 2>/dev/null || true
codesign --verify --deep --strict "$app_destination"

(cd "$output_directory" && shasum -a 256 "${archive:t}" > "${archive:t}.sha256")

echo "Creado: $archive"
echo "Verificación: $archive.sha256"
lipo -archs "$staged_app/Contents/MacOS/MiniTray"
