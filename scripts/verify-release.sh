#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
version=$(/usr/libexec/PlistBuddy \
  -c "Print :CFBundleShortVersionString" \
  "$project_root/Resources/Info.plist")
release_dir="${ENVLATCH_RELEASE_DIR:-$project_root/dist}"
app="${ENVLATCH_SOURCE_APP:-$project_root/dist/EnvLatch.app}"
architecture=$(lipo -archs "$app/Contents/MacOS/EnvLatch" | tr " " "-")
artifact_stem="EnvLatch-$version-macos-$architecture"
archive="$release_dir/$artifact_stem.zip"
dmg="$release_dir/$artifact_stem.dmg"

for artifact in "$archive" "$archive.sha256" "$dmg" "$dmg.sha256"; do
  if [[ ! -f "$artifact" ]]; then
    echo "Missing signed release artifact: $artifact" >&2
    exit 1
  fi
done

test_root=$(mktemp -d)
archive_root="$test_root/archive"
mount_dir="$test_root/mount"
mkdir -p "$archive_root" "$mount_dir"
mounted=0

cleanup() {
  if (( mounted )); then
    hdiutil detach "$mount_dir" >/dev/null 2>&1 || true
  fi
  rm -rf "$test_root"
}
trap cleanup EXIT

(
  cd "$release_dir"
  shasum -a 256 -c "${archive:t}.sha256"
  shasum -a 256 -c "${dmg:t}.sha256"
)

ditto -x -k "$archive" "$archive_root"
archive_app="$archive_root/EnvLatch.app"
test -d "$archive_app"
diff -qr "$app" "$archive_app" >/dev/null
codesign --verify --deep --strict --verbose=2 "$archive_app"
xcrun stapler validate "$archive_app"
spctl --assess --type execute --verbose=2 "$archive_app"

hdiutil verify "$dmg" >/dev/null
codesign --verify --verbose=2 "$dmg"
xcrun stapler validate "$dmg"
spctl --assess \
  --type open \
  --context context:primary-signature \
  --verbose=2 \
  "$dmg"
hdiutil attach -nobrowse -readonly -mountpoint "$mount_dir" "$dmg" >/dev/null
mounted=1

typeset -a payloads
payloads=("$mount_dir"/*(DN))
if (( ${#payloads} != 4 )); then
  echo "Expected exactly four top-level DMG payloads." >&2
  exit 1
fi
test -d "$mount_dir/EnvLatch.app"
test -x "$mount_dir/Install EnvLatch.command"
test -f "$mount_dir/NOTARIZED RELEASE - READ ME.txt"
test -f "$mount_dir/LICENSE.txt"
diff -qr "$app" "$mount_dir/EnvLatch.app" >/dev/null
cmp "$script_dir/install-preview.sh" "$mount_dir/Install EnvLatch.command"
cmp \
  "$project_root/Resources/NotarizedRelease.txt" \
  "$mount_dir/NOTARIZED RELEASE - READ ME.txt"
cmp "$project_root/LICENSE" "$mount_dir/LICENSE.txt"
codesign --verify --deep --strict --verbose=2 "$mount_dir/EnvLatch.app"
xcrun stapler validate "$mount_dir/EnvLatch.app"
spctl --assess --type execute --verbose=2 "$mount_dir/EnvLatch.app"

success_root="$test_root/success"
ENVLATCH_APPLICATION_DIR="$success_root/Applications" \
ENVLATCH_BIN_DIR="$success_root/bin" \
ENVLATCH_USER_HOME="$success_root/user" \
ENVLATCH_SKILL_DIR="$success_root/user/.agents/skills/envlatch" \
ENVLATCH_VERIFY_INSTALL=0 \
  "$mount_dir/Install EnvLatch.command" >/dev/null

installed_app="$success_root/Applications/EnvLatch.app"
installed_cli="$success_root/bin/envlatch"
canonical_skill="$success_root/user/.agents/skills/envlatch"
codesign --verify --deep --strict --verbose=2 "$installed_app"
spctl --assess --type execute --verbose=2 "$installed_app"
test "$("$installed_cli" --version)" = "EnvLatch $version"
test "${installed_cli:A}" = "${installed_app:A}/Contents/MacOS/EnvLatch"
help_output=$("$installed_cli" help)
[[ "$help_output" == *"envlatch run --using <saved-key> --using <saved-key>"* ]]
[[ "$help_output" == *"envlatch groups create <group-name>"* ]]
grep -Fq \
  'envlatch run --using <saved-key-name> --using <saved-key-name>' \
  "$canonical_skill/SKILL.md"
grep -Fq \
  'envlatch groups create "<group-name>"' \
  "$canonical_skill/SKILL.md"
grep -Fq \
  'keychain_visibility_warning=sandboxed_zero_is_inconclusive' \
  "$canonical_skill/SKILL.md"
for skill_link in \
  "$success_root/user/.codex/skills/envlatch" \
  "$success_root/user/.claude/skills/envlatch" \
  "$success_root/user/.gemini/skills/envlatch"; do
  test "${skill_link:A}" = "${canonical_skill:A}"
done

rollback_root="$test_root/rollback"
old_app="$rollback_root/Applications/EnvLatch.app"
mkdir -p "$old_app" "$rollback_root/bin" "$rollback_root/user"
print -r -- "restore-me" > "$old_app/rollback-marker"

set +e
ENVLATCH_APPLICATION_DIR="$rollback_root/Applications" \
ENVLATCH_BIN_DIR="$rollback_root/bin" \
ENVLATCH_USER_HOME="$rollback_root/user" \
ENVLATCH_SKILL_DIR="$rollback_root/user/.agents/skills/envlatch" \
ENVLATCH_VERIFY_INSTALL=1 \
  "$mount_dir/Install EnvLatch.command" >/dev/null 2>&1
rollback_status=$?
set -e

test "$rollback_status" -ne 0
test "$(cat "$old_app/rollback-marker")" = "restore-me"

signature_info=$(codesign -dvvv "$app" 2>&1)
[[ "$signature_info" == *"Authority=Developer ID Application:"* ]]
[[ "$signature_info" == *"TeamIdentifier="* ]]
[[ "$signature_info" == *"Runtime Version="* ]]
[[ "$signature_info" != *"Signature=adhoc"* ]]

dmg_signature_info=$(codesign -dvvv "$dmg" 2>&1)
[[ "$dmg_signature_info" == *"Authority=Developer ID Application:"* ]]
[[ "$dmg_signature_info" != *"Signature=adhoc"* ]]

echo "archive_checksum=passed"
echo "dmg_checksum=passed"
echo "dmg_payloads=4"
echo "architecture=$architecture"
echo "signature=Developer ID Application"
echo "notarization=stapled"
echo "gatekeeper=accepted"
echo "isolated_install=passed"
echo "induced_failure_rollback=passed"
