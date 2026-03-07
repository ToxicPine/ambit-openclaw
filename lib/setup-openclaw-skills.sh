#!/bin/bash
set -euo pipefail

# Idempotent setup of ambit-skills for openclaw.
# Runs as a regular user with HOME, git on PATH.

AGENTS_SKILLS="$HOME/.agents/skills"
MARKER="$HOME/.agents/.skills-installed"

[ -f "$MARKER" ] && exit 0

mkdir -p "$AGENTS_SKILLS"

# Clone ambit-skills repo and install all skill bundles
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
git clone --depth 1 https://github.com/ToxicPine/ambit-skills.git "$tmpdir/ambit-skills"

for skill in "$tmpdir/ambit-skills/skills"/*/; do
  [ -d "$skill" ] || continue
  skill_name=$(basename "$skill")
  if [ ! -d "$AGENTS_SKILLS/$skill_name" ]; then
    cp -r "$skill" "$AGENTS_SKILLS/$skill_name"
  fi
done

# Ensure ~/.claude/skills and ~/.openclaw/skills symlink to ~/.agents/skills
for alias_dir in "$HOME/.claude" "$HOME/.openclaw"; do
  mkdir -p "$alias_dir"
  skills_alias="$alias_dir/skills"
  if [ ! -e "$skills_alias" ]; then
    ln -s "$AGENTS_SKILLS" "$skills_alias"
  fi
done

touch "$MARKER"
