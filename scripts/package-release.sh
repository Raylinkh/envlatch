#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
version="0.1.0"
app="$project_root/dist/EnvLatch.app"
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
architecture=$(lipo -archs "$app/Contents/MacOS/EnvLatch" | tr " " "-")
archive="$project_root/dist/EnvLatch-$version-macos-$architecture.zip"
checksum="$archive.sha256"

release_stage=$(mktemp -d)
submission_archive="$release_stage/EnvLatch-$version-macos-$architecture.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$submission_archive"
xcrun notarytool submit "$submission_archive" \
  --keychain-profile "$notary_profile" \
  --wait
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

if [[ -e "$archive" || -e "$checksum" ]]; then
  release_stamp=$(date +%Y%m%d-%H%M%S)
  [[ ! -e "$archive" ]] || mv "$archive" "$project_root/dist/EnvLatch-$version-macos-$architecture.previous-$release_stamp.zip"
  [[ ! -e "$checksum" ]] || mv "$checksum" "$project_root/dist/EnvLatch-$version-macos-$architecture.previous-$release_stamp.zip.sha256"
fi

ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
(
  cd "$project_root/dist"
  shasum -a 256 "${archive:t}" > "${checksum:t}"
)
rm "$submission_archive"
rmdir "$release_stage"

echo "Release archive: $archive"
echo "Checksum: $checksum"
