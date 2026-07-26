#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
app="$project_root/dist/EnvLatch.app"
version=$(/usr/libexec/PlistBuddy \
  -c "Print :CFBundleShortVersionString" \
  "$project_root/Resources/Info.plist")

ENVLATCH_CODESIGN_IDENTITY=- "$script_dir/build-app.sh"
codesign --verify --deep --strict "$app"
signature_info=$(codesign -dvvv "$app" 2>&1)
if [[ "$signature_info" != *"Signature=adhoc"* ]]; then
  echo "Expected an ad-hoc signature for the unsigned preview." >&2
  exit 1
fi

architecture=$(lipo -archs "$app/Contents/MacOS/EnvLatch" | tr " " "-")
artifact_name="EnvLatch-$version-macos-$architecture-unsigned.dmg"
dmg="$project_root/dist/$artifact_name"
checksum="$dmg.sha256"
release_stamp="$(date +%Y%m%d-%H%M%S)-$$"

if [[ -e "$dmg" ]]; then
  mv "$dmg" "$project_root/dist/$artifact_name.previous-$release_stamp"
fi
if [[ -e "$checksum" ]]; then
  mv "$checksum" "$project_root/dist/$artifact_name.sha256.previous-$release_stamp"
fi

stage_root=$(mktemp -d)
trap 'rm -rf "$stage_root"' EXIT
stage="$stage_root/EnvLatch $version Unsigned Preview"
mkdir -p "$stage"
ditto "$app" "$stage/EnvLatch.app"
install -m 755 "$script_dir/install-preview.sh" "$stage/Install EnvLatch.command"
install -m 644 \
  "$project_root/Resources/UnsignedPreview.txt" \
  "$stage/UNSIGNED PREVIEW - READ ME.txt"
install -m 644 "$project_root/LICENSE" "$stage/LICENSE.txt"

hdiutil create \
  -volname "EnvLatch $version Unsigned Preview" \
  -srcfolder "$stage" \
  -format UDZO \
  -ov \
  "$dmg"
hdiutil verify "$dmg"

(
  cd "$project_root/dist"
  shasum -a 256 "$artifact_name" > "$artifact_name.sha256"
)

echo "Unsigned preview DMG: $dmg"
echo "Checksum: $checksum"
