#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
app_name="EnvLatch.app"
dist_dir="$project_root/dist"
output_app="$dist_dir/$app_name"
signing_identity="${ENVLATCH_CODESIGN_IDENTITY:--}"

cd "$project_root"
swift build -c release --product EnvLatch
binary_dir=$(swift build -c release --show-bin-path)
resource_bundle="$binary_dir/EnvLatch_EnvLatch.bundle"

stage_root=$(mktemp -d)
stage_app="$stage_root/$app_name"
mkdir -p "$stage_app/Contents/MacOS" "$stage_app/Contents/Resources"
install -m 755 "$binary_dir/EnvLatch" "$stage_app/Contents/MacOS/EnvLatch"
install -m 644 "$project_root/Resources/Info.plist" "$stage_app/Contents/Info.plist"
install -m 644 "$project_root/Resources/AppIcon.icns" "$stage_app/Contents/Resources/AppIcon.icns"
install -m 755 "$project_root/scripts/pair-agents.sh" "$stage_app/Contents/Resources/pair-agents.sh"
ditto "$project_root/AgentSkill/envlatch" "$stage_app/Contents/Resources/envlatch-skill"
ditto "$project_root/Sources/EnvLatch/Resources/ProviderIcons" "$stage_app/Contents/Resources/ProviderIcons"
compiled_chinese="$resource_bundle/zh-hans.lproj"
if [[ ! -d "$compiled_chinese" ]]; then
  compiled_chinese="$resource_bundle/zh-Hans.lproj"
fi
if [[ ! -d "$compiled_chinese" ]]; then
  echo "Missing compiled Simplified Chinese localization in $resource_bundle" >&2
  exit 1
fi
ditto "$compiled_chinese" "$stage_app/Contents/Resources/zh-Hans.lproj"

if [[ "$signing_identity" == "-" ]]; then
  codesign --force --sign - --timestamp=none "$stage_app"
else
  codesign --force --sign "$signing_identity" --options runtime --timestamp "$stage_app"
fi
codesign --verify --deep --strict "$stage_app"

mkdir -p "$dist_dir"
backup_app="$stage_root/previous.app"
if [[ -e "$output_app" ]]; then
  mv "$output_app" "$backup_app"
fi
if ! mv "$stage_app" "$output_app"; then
  if [[ -e "$backup_app" ]]; then
    mv "$backup_app" "$output_app"
  fi
  exit 1
fi
if [[ -e "$backup_app" ]]; then
  rm -rf "$backup_app"
fi
rmdir "$stage_root"

echo "$output_app"
