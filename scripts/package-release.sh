#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
version=$(/usr/libexec/PlistBuddy \
  -c "Print :CFBundleShortVersionString" \
  "$project_root/Resources/Info.plist")
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

notarize_artifact() {
  local artifact="$1"
  local result="$2"
  local log="$3"

  xcrun notarytool submit "$artifact" \
    --keychain-profile "$notary_profile" \
    --wait \
    --output-format json > "$result"

  local notary_status
  local submission_id
  notary_status=$(/usr/bin/plutil -extract status raw -o - "$result")
  submission_id=$(/usr/bin/plutil -extract id raw -o - "$result")
  xcrun notarytool log "$submission_id" \
    --keychain-profile "$notary_profile" \
    "$log"

  if [[ "$notary_status" != "Accepted" ]]; then
    echo "Apple notarization did not accept $artifact. See $log." >&2
    return 1
  fi
  echo "Notarization accepted: ${artifact:t} ($submission_id)"
}

rotate_if_present() {
  local artifact_path="$1"
  if [[ -e "$artifact_path" ]]; then
    mv "$artifact_path" "$artifact_path.previous-$release_stamp"
  fi
}

ENVLATCH_CODESIGN_IDENTITY="$signing_identity" "$script_dir/build-app.sh"
codesign --verify --deep --strict --verbose=2 "$app"
architecture=$(lipo -archs "$app/Contents/MacOS/EnvLatch" | tr " " "-")
artifact_stem="EnvLatch-$version-macos-$architecture"
archive="$project_root/dist/$artifact_stem.zip"
archive_checksum="$archive.sha256"
dmg="$project_root/dist/$artifact_stem.dmg"
dmg_checksum="$dmg.sha256"
archive_result="$project_root/dist/$artifact_stem.zip.notary-result.json"
archive_log="$project_root/dist/$artifact_stem.zip.notary-log.json"
dmg_result="$project_root/dist/$artifact_stem.dmg.notary-result.json"
dmg_log="$project_root/dist/$artifact_stem.dmg.notary-log.json"
release_stamp="$(date +%Y%m%d-%H%M%S)-$$"

for artifact in \
  "$archive" \
  "$archive_checksum" \
  "$dmg" \
  "$dmg_checksum" \
  "$archive_result" \
  "$archive_log" \
  "$dmg_result" \
  "$dmg_log"; do
  rotate_if_present "$artifact"
done

release_stage=$(mktemp -d)
dmg_stage_root=$(mktemp -d)
cleanup() {
  rm -rf "$release_stage" "$dmg_stage_root"
}
trap cleanup EXIT

submission_archive="$release_stage/$artifact_stem.zip"
ditto -c -k --sequesterRsrc --keepParent "$app" "$submission_archive"
notarize_artifact "$submission_archive" "$archive_result" "$archive_log"
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"

ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
(
  cd "$project_root/dist"
  shasum -a 256 "${archive:t}" > "${archive_checksum:t}"
)

dmg_stage="$dmg_stage_root/EnvLatch $version"
mkdir -p "$dmg_stage"
ditto "$app" "$dmg_stage/EnvLatch.app"
install -m 755 "$script_dir/install-preview.sh" "$dmg_stage/Install EnvLatch.command"
install -m 644 \
  "$project_root/Resources/NotarizedRelease.txt" \
  "$dmg_stage/NOTARIZED RELEASE - READ ME.txt"
install -m 644 "$project_root/LICENSE" "$dmg_stage/LICENSE.txt"

hdiutil create \
  -volname "EnvLatch $version" \
  -srcfolder "$dmg_stage" \
  -format UDZO \
  -ov \
  "$dmg"
hdiutil verify "$dmg"
codesign --force --sign "$signing_identity" --timestamp "$dmg"
codesign --verify --verbose=2 "$dmg"

notarize_artifact "$dmg" "$dmg_result" "$dmg_log"
xcrun stapler staple "$dmg"
xcrun stapler validate "$dmg"
hdiutil verify "$dmg"
spctl --assess \
  --type open \
  --context context:primary-signature \
  --verbose=2 \
  "$dmg"

(
  cd "$project_root/dist"
  shasum -a 256 "${dmg:t}" > "${dmg_checksum:t}"
)

echo "Release archive: $archive"
echo "Archive checksum: $archive_checksum"
echo "Release disk image: $dmg"
echo "Disk image checksum: $dmg_checksum"
echo "Archive notary log: $archive_log"
echo "Disk image notary log: $dmg_log"
