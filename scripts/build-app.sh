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

stage_root=$(mktemp -d)
stage_app="$stage_root/$app_name"
mkdir -p "$stage_app/Contents/MacOS" "$stage_app/Contents/Resources"
install -m 755 "$binary_dir/EnvLatch" "$stage_app/Contents/MacOS/EnvLatch"
install -m 644 "$project_root/Resources/Info.plist" "$stage_app/Contents/Info.plist"
install -m 755 "$project_root/scripts/pair-agents.sh" "$stage_app/Contents/Resources/pair-agents.sh"
ditto "$project_root/AgentSkill/envlatch" "$stage_app/Contents/Resources/envlatch-skill"

if [[ "$signing_identity" == "-" ]]; then
  codesign --force --sign - --timestamp=none "$stage_app"
else
  codesign --force --sign "$signing_identity" --options runtime --timestamp "$stage_app"
fi
codesign --verify --deep --strict "$stage_app"

mkdir -p "$dist_dir"
if [[ -e "$output_app" ]]; then
  build_stamp=$(date +%Y%m%d-%H%M%S)
  mv "$output_app" "$dist_dir/EnvLatch.previous-$build_stamp.app"
fi
mv "$stage_app" "$output_app"
rmdir "$stage_root"

echo "$output_app"
