#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
project_root="${script_dir:h}"
application_dir="${ENVLATCH_APPLICATION_DIR:-$HOME/Applications}"
binary_dir="${ENVLATCH_BIN_DIR:-$HOME/.local/bin}"
source_app="$project_root/dist/EnvLatch.app"
installed_app="$application_dir/EnvLatch.app"
legacy_app="$application_dir/AgentKeyring.app"
install_stamp=$(date +%Y%m%d-%H%M%S)

"$script_dir/build-app.sh"
mkdir -p "$application_dir" "$binary_dir"

if [[ -e "$installed_app" ]]; then
  mv "$installed_app" "$application_dir/EnvLatch.previous-$install_stamp.app"
fi
if [[ -e "$legacy_app" ]]; then
  mv "$legacy_app" "$application_dir/AgentKeyring.previous-$install_stamp.app"
fi
ditto "$source_app" "$installed_app"

ENVLATCH_BIN_DIR="$binary_dir" "$installed_app/Contents/Resources/pair-agents.sh"

codesign --verify --deep --strict "$installed_app"
"$binary_dir/envlatch" doctor

echo "Installed app: $installed_app"
echo "Installed CLI: $binary_dir/envlatch"
