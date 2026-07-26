#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
pair_stamp="$(date +%Y%m%d-%H%M%S)-$$"

if [[ "$script_dir" == */Contents/Resources ]]; then
  agent_executable="${script_dir:h}/MacOS/EnvLatch"
  skill_source="$script_dir/envlatch-skill"
else
  project_root="${script_dir:h}"
  agent_executable="$project_root/dist/EnvLatch.app/Contents/MacOS/EnvLatch"
  skill_source="$project_root/AgentSkill/envlatch"
fi

user_home="${ENVLATCH_USER_HOME:-$HOME}"
binary_dir="${ENVLATCH_BIN_DIR:-$user_home/.local/bin}"
cli_link="$binary_dir/envlatch"
legacy_cli_link="$binary_dir/agent-keyring"
canonical_skill="${ENVLATCH_SKILL_DIR:-$user_home/.agents/skills/envlatch}"
legacy_canonical_skill="$user_home/.agents/skills/agent-keyring"
staged_cli="$binary_dir/.envlatch.install-$pair_stamp"
staged_skill="${canonical_skill:h}/.envlatch.install-$pair_stamp"

if [[ ! -x "$agent_executable" ]]; then
  echo "EnvLatch executable is missing: $agent_executable" >&2
  exit 1
fi
if [[ ! -f "$skill_source/SKILL.md" ]]; then
  echo "EnvLatch skill is missing: $skill_source/SKILL.md" >&2
  exit 1
fi

mkdir -p "$binary_dir" "${canonical_skill:h}"

needs_cli=1
if [[ -e "$cli_link" || -L "$cli_link" ]]; then
  [[ "${cli_link:A}" != "${agent_executable:A}" ]] || needs_cli=0
fi
if (( needs_cli )); then
  ln -s "$agent_executable" "$staged_cli"
fi

needs_skill=1
if [[ -d "$canonical_skill" ]] && diff -qr "$skill_source" "$canonical_skill" >/dev/null; then
  needs_skill=0
fi
if (( needs_skill )); then
  ditto "$skill_source" "$staged_skill"
  diff -qr "$skill_source" "$staged_skill" >/dev/null
fi

typeset -a skill_links legacy_skill_links staged_skill_links skill_link_needs
for agent_home in "$user_home/.codex" "$user_home/.claude" "$user_home/.gemini"; do
  skill_parent="$agent_home/skills"
  skill_link="$skill_parent/envlatch"
  legacy_skill_link="$skill_parent/agent-keyring"
  staged_skill_link="$skill_parent/.envlatch.install-$pair_stamp"
  mkdir -p "$skill_parent"

  needs_link=1
  if [[ -e "$skill_link" || -L "$skill_link" ]]; then
    [[ "${skill_link:A}" != "${canonical_skill:A}" ]] || needs_link=0
  fi
  if (( needs_link )); then
    ln -s "$canonical_skill" "$staged_skill_link"
  fi

  skill_links+=("$skill_link")
  legacy_skill_links+=("$legacy_skill_link")
  staged_skill_links+=("$staged_skill_link")
  skill_link_needs+=("$needs_link")
done

typeset -a moved_targets moved_backups installed_targets
rollback_active=1

backup_if_present() {
  local target="$1"
  local backup="$2"
  if [[ -e "$target" || -L "$target" ]]; then
    mv "$target" "$backup"
    moved_targets+=("$target")
    moved_backups+=("$backup")
  fi
}

install_staged() {
  local staged="$1"
  local target="$2"
  mv "$staged" "$target"
  installed_targets+=("$target")
}

rollback_pairing() {
  local exit_status=$?
  if (( ! rollback_active || exit_status == 0 )); then
    return "$exit_status"
  fi

  set +e
  for target in "${installed_targets[@]}"; do
    if [[ -e "$target" || -L "$target" ]]; then
      mv "$target" "$target.failed-$pair_stamp"
    fi
  done
  local index
  for (( index=${#moved_targets}; index>=1; index-- )); do
    if [[ -e "${moved_backups[$index]}" || -L "${moved_backups[$index]}" ]]; then
      mv "${moved_backups[$index]}" "${moved_targets[$index]}"
    fi
  done
  return "$exit_status"
}
trap rollback_pairing EXIT

backup_if_present "$legacy_cli_link" "$binary_dir/agent-keyring.previous-$pair_stamp"
backup_if_present "$legacy_canonical_skill" "${legacy_canonical_skill:h}/agent-keyring.previous-$pair_stamp"

if (( needs_cli )); then
  backup_if_present "$cli_link" "$binary_dir/envlatch.previous-$pair_stamp"
  install_staged "$staged_cli" "$cli_link"
fi

if (( needs_skill )); then
  backup_if_present "$canonical_skill" "${canonical_skill:h}/envlatch.previous-$pair_stamp"
  install_staged "$staged_skill" "$canonical_skill"
fi

for (( index=1; index<=${#skill_links}; index++ )); do
  backup_if_present \
    "${legacy_skill_links[$index]}" \
    "${legacy_skill_links[$index]:h}/agent-keyring.previous-$pair_stamp"
  if (( skill_link_needs[$index] )); then
    backup_if_present \
      "${skill_links[$index]}" \
      "${skill_links[$index]:h}/envlatch.previous-$pair_stamp"
    install_staged "${staged_skill_links[$index]}" "${skill_links[$index]}"
  fi
done

if [[ "${ENVLATCH_VERIFY_INSTALL:-0}" == "1" ]]; then
  "$cli_link" doctor
fi

rollback_active=0
trap - EXIT

echo "EnvLatch CLI: $cli_link"
echo "Shared skill: $canonical_skill"
echo "Discovery links: Codex, Claude Code, Gemini CLI"
echo "Any agent or host can register with: envlatch pair <name>"
