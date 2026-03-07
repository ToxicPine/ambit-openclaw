#!/bin/bash
set -euo pipefail

# Background daemon: rebuild Home Manager from user's nixcfg if modified.
# Runs as each user via the daemon user="*" mechanism.

for f in flake.nix flake.lock home.nix system.nix users.nix; do
  if ! cmp -s "$HOME/.nixcfg/$f" "/etc/nixcfg/$f" 2>/dev/null; then
    echo "Rebuilding Home Manager from user config for $USER..." >&2
    cd ~/.nixcfg && home-manager switch --flake . \
      || echo "Warning: Home Manager rebuild failed for $USER" >&2
    exit 0
  fi
done
