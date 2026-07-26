#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
source_app="${ENVLATCH_SOURCE_APP:-$script_dir/EnvLatch.app}"
application_dir="${ENVLATCH_APPLICATION_DIR:-$HOME/Applications}"
binary_dir="${ENVLATCH_BIN_DIR:-$HOME/.local/bin}"
verify_install="${ENVLATCH_VERIFY_INSTALL:-1}"
installed_app="$application_dir/EnvLatch.app"
legacy_app="$application_dir/AgentKeyring.app"
install_stamp="$(date +%Y%m%d-%H%M%S)-$$"
staged_app="$application_dir/.EnvLatch.install-$install_stamp.app"
installed_backup="$application_dir/EnvLatch.previous-$install_stamp.app"
legacy_backup="$application_dir/AgentKeyring.previous-$install_stamp.app"

if [[ ! -d "$source_app" ]]; then
  echo "EnvLatch.app is missing beside this installer: $source_app" >&2
  exit 1
fi

codesign --verify --deep --strict "$source_app"
mkdir -p "$application_dir" "$binary_dir"
ditto "$source_app" "$staged_app"
codesign --verify --deep --strict "$staged_app"

installed_was_backed_up=0
legacy_was_backed_up=0
installed_new_app=0
rollback_active=1

rollback_install() {
  local exit_status=$?
  if (( ! rollback_active || exit_status == 0 )); then
    return "$exit_status"
  fi

  set +e
  if (( installed_new_app )) &&
      [[ -e "$installed_app" || -L "$installed_app" ]]; then
    mv "$installed_app" "$application_dir/EnvLatch.failed-$install_stamp.app"
  fi
  if (( installed_was_backed_up )) &&
      [[ -e "$installed_backup" || -L "$installed_backup" ]]; then
    mv "$installed_backup" "$installed_app"
  fi
  if (( legacy_was_backed_up )) &&
      [[ -e "$legacy_backup" || -L "$legacy_backup" ]]; then
    mv "$legacy_backup" "$legacy_app"
  fi
  return "$exit_status"
}
trap rollback_install EXIT

if [[ -e "$installed_app" || -L "$installed_app" ]]; then
  mv "$installed_app" "$installed_backup"
  installed_was_backed_up=1
fi
if [[ -e "$legacy_app" || -L "$legacy_app" ]]; then
  mv "$legacy_app" "$legacy_backup"
  legacy_was_backed_up=1
fi
mv "$staged_app" "$installed_app"
installed_new_app=1

codesign --verify --deep --strict "$installed_app"
ENVLATCH_VERIFY_INSTALL="$verify_install" \
  ENVLATCH_BIN_DIR="$binary_dir" \
  "$installed_app/Contents/Resources/pair-agents.sh"

rollback_active=0
trap - EXIT

echo "Installed app: $installed_app"
echo "Installed CLI: $binary_dir/envlatch"
echo "Unsigned preview: macOS may require Privacy & Security > Open Anyway."
