#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INCLUDED_DIR="${ROOT_DIR}/included-skills"

# OpenClaw skills: highest precedence under the agent workspace; see
# https://docs.openclaw.ai/tools/creating-skills
OPENCLAW_HOME="${OPENCLAW_HOME:-$HOME/.openclaw}"
OPENCLAW_WORKSPACE="${OPENCLAW_WORKSPACE:-$OPENCLAW_HOME/workspace}"
DEST_BASE="${OPENCLAW_SKILLS_DIR:-$OPENCLAW_WORKSPACE/skills}"

FORCE=0
DRY_RUN=0

usage() {
  cat <<EOF
Usage: scripts/install-included-skills.sh [options]

Install bundled OpenClaw skills from included-skills/ into:
  ${DEST_BASE}

Environment (optional):
  OPENCLAW_SKILLS_DIR   Full path to skills directory (overrides default below)
  OPENCLAW_WORKSPACE    Workspace root (default: \${OPENCLAW_HOME}/workspace)
  OPENCLAW_HOME         OpenClaw state dir (default: \$HOME/.openclaw)

Options:
  -f, --force    Overwrite already installed skills
  -n, --dry-run  Show what would happen without copying files
  -h, --help     Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--force)
      FORCE=1
      shift
      ;;
    -n|--dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -d "$INCLUDED_DIR" ]]; then
  echo "No included-skills directory found at: $INCLUDED_DIR" >&2
  exit 1
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  mkdir -p "$DEST_BASE"
fi

installed=0
skipped=0
failed=0

shopt -s nullglob
skill_dirs=("$INCLUDED_DIR"/*)

if [[ ${#skill_dirs[@]} -eq 0 ]]; then
  echo "No skill folders found in $INCLUDED_DIR"
  exit 0
fi

echo "Source: $INCLUDED_DIR"
echo "Destination: $DEST_BASE"
[[ "$DRY_RUN" -eq 1 ]] && echo "Mode: dry-run"

for skill_path in "${skill_dirs[@]}"; do
  [[ -d "$skill_path" ]] || continue
  skill_name="$(basename "$skill_path")"
  skill_file="$skill_path/SKILL.md"
  dest_path="$DEST_BASE/$skill_name"

  if [[ ! -f "$skill_file" ]]; then
    echo "WARN  $skill_name: missing SKILL.md, skipping"
    skipped=$((skipped + 1))
    continue
  fi

  if [[ -e "$dest_path" ]]; then
    if [[ "$FORCE" -eq 1 ]]; then
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "PLAN  $skill_name: would overwrite existing skill"
      else
        rm -rf "$dest_path"
      fi
    else
      echo "SKIP  $skill_name: already installed (use --force to overwrite)"
      skipped=$((skipped + 1))
      continue
    fi
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "PLAN  $skill_name: would install"
    installed=$((installed + 1))
    continue
  fi

  if cp -R "$skill_path" "$dest_path"; then
    echo "OK    $skill_name: installed"
    installed=$((installed + 1))
  else
    echo "FAIL  $skill_name: install failed"
    failed=$((failed + 1))
  fi
done

echo
echo "Summary: installed=$installed skipped=$skipped failed=$failed"

if [[ "$failed" -gt 0 ]]; then
  exit 1
fi

cat <<'EOF'
Pick up new skills: start a new chat (/new), restart the gateway
(`openclaw gateway restart`), or run `openclaw skills list` to verify.
See https://docs.openclaw.ai/tools/creating-skills
EOF
