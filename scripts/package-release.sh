#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
version="0.1.0"
app="$project_root/dist/EnvLatch.app"
archive="$project_root/dist/EnvLatch-$version-macos.zip"
checksum="$archive.sha256"
signing_identity="${ENVLATCH_CODESIGN_IDENTITY:-}"
notary_profile="${ENVLATCH_NOTARY_PROFILE:-}"

if [[ -z "$signing_identity" ]]; then
  echo "Set ENVLATCH_CODESIGN_IDENTITY to a Developer ID Application identity." >&2
  exit 64
fi

if [[ -z "$notary_profile" ]]; then
  echo "Set ENVLATCH_NOTARY_PROFILE to an xcrun notarytool Keychain profile." >&2
  exit 64
fi

ENVLATCH_CODESIGN_IDENTITY="$signing_identity" "$script_dir/build-app.sh"
codesign --verify --deep --strict --verbose=2 "$app"

release_stage=$(mktemp -d)
submission_archive="$release_stage/EnvLatch-$version-macos.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$submission_archive"
xcrun notarytool submit "$submission_archive" \
  --keychain-profile "$notary_profile" \
  --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

if [[ -e "$archive" || -e "$checksum" ]]; then
  release_stamp=$(date +%Y%m%d-%H%M%S)
  [[ ! -e "$archive" ]] || mv "$archive" "$project_root/dist/EnvLatch-$version-macos.previous-$release_stamp.zip"
  [[ ! -e "$checksum" ]] || mv "$checksum" "$project_root/dist/EnvLatch-$version-macos.previous-$release_stamp.zip.sha256"
fi

ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
shasum -a 256 "$archive" > "$checksum"
rm "$submission_archive"
rmdir "$release_stage"

echo "Release archive: $archive"
echo "Checksum: $checksum"
