#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
version=$(/usr/libexec/PlistBuddy \
  -c "Print :CFBundleShortVersionString" \
  "$project_root/Resources/Info.plist")
artifact="EnvLatch-$version-macos-arm64-unsigned.dmg"
dmg="$project_root/dist/$artifact"
source_app="$project_root/dist/EnvLatch.app"

if [[ ! -f "$dmg" || ! -f "$dmg.sha256" ]]; then
  echo "Unsigned arm64 preview artifacts are missing under dist/." >&2
  exit 1
fi

test_root=$(mktemp -d)
mount_dir="$test_root/mount"
mkdir -p "$mount_dir"
mounted=0

cleanup() {
  if (( mounted )); then
    hdiutil detach "$mount_dir" >/dev/null 2>&1 || true
  fi
  rm -rf "$test_root"
}
trap cleanup EXIT

(
  cd "$project_root/dist"
  shasum -a 256 -c "$artifact.sha256"
)
hdiutil verify "$dmg" >/dev/null
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
test -f "$mount_dir/UNSIGNED PREVIEW - READ ME.txt"
test -f "$mount_dir/LICENSE.txt"
diff -qr "$source_app" "$mount_dir/EnvLatch.app" >/dev/null
cmp \
  "$script_dir/install-preview.sh" \
  "$mount_dir/Install EnvLatch.command"
cmp \
  "$project_root/Resources/UnsignedPreview.txt" \
  "$mount_dir/UNSIGNED PREVIEW - READ ME.txt"
cmp "$project_root/LICENSE" "$mount_dir/LICENSE.txt"
cmp \
  "$script_dir/pair-agents.sh" \
  "$mount_dir/EnvLatch.app/Contents/Resources/pair-agents.sh"
test "$(lipo -archs "$mount_dir/EnvLatch.app/Contents/MacOS/EnvLatch")" = "arm64"
signature_info=$(codesign -dvvv "$mount_dir/EnvLatch.app" 2>&1)
[[ "$signature_info" == *"Signature=adhoc"* ]]

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
codesign --verify --deep --strict "$installed_app"
test "$("$installed_cli" --version)" = "EnvLatch $version"
test "${installed_cli:A}" = "${installed_app:A}/Contents/MacOS/EnvLatch"
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

set +e
spctl --assess --type execute "$installed_app" >/dev/null 2>&1
gatekeeper_status=$?
set -e
test "$gatekeeper_status" -ne 0

echo "dmg_payloads=4"
echo "architecture=arm64"
echo "signature=adhoc"
echo "isolated_install=passed"
echo "induced_failure_rollback=passed"
echo "gatekeeper_expected_rejection_exit=$gatekeeper_status"
