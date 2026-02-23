#!/bin/bash
# setup-skills.sh <username> <uid>
#
# Idempotently installs /opt/skills/* into the user's ~/.agents/skills/ as
# symlinks, then ensures ~/.claude/skills and ~/.openclaw/skills point at
# ~/.agents/skills so all three agent conventions resolve to the same place.
#
# Safe to call on every boot — existing correct symlinks are left untouched,
# broken or missing ones are (re)created. Never touches files the user has
# placed under those dirs themselves.

set -euo pipefail

USERNAME="$1"
UID_VAL="$2"
HOME_DIR="/home/$USERNAME"

AGENTS_SKILLS="$HOME_DIR/.agents/skills"

# Ensure the canonical skills dir exists and is owned by the user.
install -d -o "$UID_VAL" -g "$UID_VAL" -m 755 \
  "$HOME_DIR/.agents" \
  "$AGENTS_SKILLS"

# For each skill in /opt/skills, create or repair the symlink.
if [ -d /opt/skills ]; then
  for skill_dir in /opt/skills/*/; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    link="$AGENTS_SKILLS/$skill_name"

    # Remove the link only if it is broken (target gone) or points somewhere wrong.
    if [ -L "$link" ]; then
      target="$(readlink "$link")"
      if [ "$target" != "$skill_dir" ] && [ "$target" != "/opt/skills/$skill_name" ]; then
        rm "$link"
      fi
    elif [ -e "$link" ]; then
      # A real file/dir is here — the user owns it; leave it alone (workspace override).
      continue
    fi

    # Create the symlink if it doesn't exist yet.
    if [ ! -L "$link" ]; then
      ln -s "/opt/skills/$skill_name" "$link"
      chown -h "$UID_VAL:$UID_VAL" "$link"
    fi
  done
fi

# Ensure ~/.claude/skills and ~/.openclaw/skills are symlinks into ~/.agents/skills.
# If the user has a real directory there already, leave it alone.
for alias_dir in "$HOME_DIR/.claude" "$HOME_DIR/.openclaw"; do
  skills_alias="$alias_dir/skills"

  install -d -o "$UID_VAL" -g "$UID_VAL" -m 755 "$alias_dir"

  if [ -L "$skills_alias" ]; then
    target="$(readlink "$skills_alias")"
    if [ "$target" != "$AGENTS_SKILLS" ]; then
      rm "$skills_alias"
    fi
  elif [ -e "$skills_alias" ]; then
    # Real directory — user owns it; leave it alone.
    continue
  fi

  if [ ! -L "$skills_alias" ]; then
    ln -s "$AGENTS_SKILLS" "$skills_alias"
    chown -h "$UID_VAL:$UID_VAL" "$skills_alias"
  fi
done
