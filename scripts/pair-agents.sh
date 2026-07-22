#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
pair_stamp=$(date +%Y%m%d-%H%M%S)

if [[ "$script_dir" == */Contents/Resources ]]; then
  agent_executable="${script_dir:h}/MacOS/AgentKeyring"
  skill_source="$script_dir/agent-keyring-skill"
else
  project_root="${script_dir:h}"
  agent_executable="$project_root/dist/AgentKeyring.app/Contents/MacOS/AgentKeyring"
  skill_source="$project_root/AgentSkill/agent-keyring"
fi

user_home="${AGENT_KEYRING_USER_HOME:-$HOME}"
binary_dir="${AGENT_KEYRING_BIN_DIR:-$user_home/.local/bin}"
cli_link="$binary_dir/agent-keyring"
canonical_skill="${AGENT_KEYRING_SKILL_DIR:-$user_home/.agents/skills/agent-keyring}"

if [[ ! -x "$agent_executable" ]]; then
  echo "AgentKeyring executable is missing: $agent_executable" >&2
  exit 1
fi
if [[ ! -f "$skill_source/SKILL.md" ]]; then
  echo "AgentKeyring skill is missing: $skill_source/SKILL.md" >&2
  exit 1
fi

mkdir -p "$binary_dir" "${canonical_skill:h}"

if [[ -e "$cli_link" || -L "$cli_link" ]]; then
  current_cli="${cli_link:A}"
  if [[ "$current_cli" != "${agent_executable:A}" ]]; then
    mv "$cli_link" "$binary_dir/agent-keyring.previous-$pair_stamp"
  fi
fi
if [[ ! -e "$cli_link" && ! -L "$cli_link" ]]; then
  ln -s "$agent_executable" "$cli_link"
fi

if [[ -e "$canonical_skill" || -L "$canonical_skill" ]]; then
  if [[ ! -d "$canonical_skill" ]] || ! diff -qr "$skill_source" "$canonical_skill" >/dev/null; then
    mv "$canonical_skill" "${canonical_skill:h}/agent-keyring.previous-$pair_stamp"
  fi
fi
if [[ ! -e "$canonical_skill" && ! -L "$canonical_skill" ]]; then
  ditto "$skill_source" "$canonical_skill"
fi

for agent_home in "$user_home/.codex" "$user_home/.claude" "$user_home/.gemini"; do
  skill_parent="$agent_home/skills"
  skill_link="$skill_parent/agent-keyring"
  mkdir -p "$skill_parent"
  if [[ -e "$skill_link" || -L "$skill_link" ]]; then
    current_skill="${skill_link:A}"
    if [[ "$current_skill" != "${canonical_skill:A}" ]]; then
      mv "$skill_link" "$skill_parent/agent-keyring.previous-$pair_stamp"
    fi
  fi
  if [[ ! -e "$skill_link" && ! -L "$skill_link" ]]; then
    ln -s "$canonical_skill" "$skill_link"
  fi
done

echo "AgentKeyring CLI: $cli_link"
echo "Shared skill: $canonical_skill"
echo "Paired agents: Codex, Claude Code, Gemini CLI"
