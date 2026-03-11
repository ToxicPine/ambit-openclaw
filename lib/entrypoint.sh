#!/bin/bash
set -euo pipefail

DATA="/data"

resolve_uid() {
  jq -r --arg u "$1" '.[] | select(.name == $u) | .uid' /etc/users.json
}

run_as_user() {
  local name="$1"; shift
  local uid home user_path
  uid=$(resolve_uid "$name")
  home="/home/$name"
  user_path="$home/.nix-profile/bin:$home/.local/state/nix/profiles/home-manager/home-path/bin"

  setpriv --reuid="$uid" --regid="$uid" --init-groups \
    env HOME="$home" USER="$name" PATH="$user_path:$PATH" \
    "$@"
}

DAEMON_PIDS=()
cleanup() {
  for pid in "${DAEMON_PIDS[@]}"; do
    kill "$pid" 2>/dev/null || true
  done
  wait
}
trap cleanup EXIT TERM INT

# Runtime-mutable but reboot-reset nix store overlay on Fly volume.
# /home remains persistent under /data/homes/*.
NIX_EPHEMERAL_ROOT="$DATA/nix-ephemeral"
NIX_UPPER="$NIX_EPHEMERAL_ROOT/upper"
NIX_WORK="$NIX_EPHEMERAL_ROOT/work"
rm -rf "$NIX_UPPER" "$NIX_WORK"
mkdir -p /nix-base "$NIX_UPPER" "$NIX_WORK"
mount --bind /nix /nix-base
mount -t overlay overlay \
  -o "lowerdir=/nix-base,upperdir=$NIX_UPPER,workdir=$NIX_WORK" \
  /nix

# Nix daemon
nix-daemon &
DAEMON_PIDS+=($!)
while [ ! -S /nix/var/nix/daemon-socket/socket ]; do sleep 0.05; done

# Per-user persistent homes and Home Manager activation
while IFS=$'\t' read -r name uid; do
  persist="$DATA/homes/$name"
  home="/home/$name"

  mkdir -p "$persist" "$home"
  chown "$uid:$uid" "$persist"

  if [ ! -d "$persist/.nixcfg" ]; then
    cp -r /etc/nixcfg "$persist/.nixcfg"
    chown -R "$uid:$uid" "$persist/.nixcfg"
  fi

  mount --bind "$persist" "$home"

  hm_profiles="$home/.local/state/nix/profiles"
  hm_gcroots="$home/.local/state/home-manager/gcroots"
  activation=$(jq -r --arg u "$name" '.[$u]' /etc/activations.json)

  run_as_user "$name" mkdir -p "$hm_profiles" "$hm_gcroots"

  # Check if user's nixcfg has been modified and userRebuild is enabled
  user_modified=false
  user_rebuild=$(jq -r 'if .userRebuild == false then "false" else "true" end' /etc/entrypoint.json)
  if [ "$user_rebuild" = "true" ]; then
    for f in flake.nix flake.lock home.nix system.nix users.nix; do
      if ! cmp -s "$home/.nixcfg/$f" "/etc/nixcfg/$f" 2>/dev/null; then
        user_modified=true
        break
      fi
    done
  fi

  if [ "$user_modified" = true ]; then
    # Activate image default first so home-manager is on PATH, then rebuild
    if [ -n "$activation" ] && [ "$activation" != "null" ]; then
      run_as_user "$name" "$activation/activate" 2>/dev/null || true
    fi
    echo "Rebuilding Home Manager from user config for $name..." >&2
    run_as_user "$name" bash -c 'cd ~/.nixcfg && home-manager switch --flake .' \
      || echo "Warning: Home Manager rebuild failed for $name, using image default" >&2
  elif [ -n "$activation" ] && [ "$activation" != "null" ]; then
    run_as_user "$name" "$activation/activate" \
      || echo "Warning: Home Manager activation failed for $name" >&2
  fi

  # Ensure openclaw state dir exists and is owned by the user.
  run_as_user "$name" mkdir -p "$home/.openclaw/logs" "$home/.openclaw/workspace"

done < <(jq -r '.[] | [.name, .uid] | @tsv' /etc/users.json)

# Application daemons
# user: "*" = all users, ["a","b"] = listed users, "name" = single user, omitted = root
while IFS= read -r daemon; do
  readarray -t cmd < <(echo "$daemon" | jq -r '.command[]')
  user_field=$(echo "$daemon" | jq -c '.user // empty')

  if [ "$user_field" = '"*"' ]; then
    while IFS=$'\t' read -r name uid; do
      run_as_user "$name" "${cmd[@]}" &
      DAEMON_PIDS+=($!)
    done < <(jq -r '.[] | [.name, .uid] | @tsv' /etc/users.json)
  elif echo "$daemon" | jq -e '.user | type == "array"' >/dev/null 2>&1; then
    while IFS= read -r name; do
      run_as_user "$name" "${cmd[@]}" &
      DAEMON_PIDS+=($!)
    done < <(echo "$daemon" | jq -r '.user[]')
  elif [ -n "$user_field" ] && [ "$user_field" != '""' ]; then
    run_as_user "$(echo "$daemon" | jq -r '.user')" "${cmd[@]}" &
    DAEMON_PIDS+=($!)
  else
    "${cmd[@]}" &
    DAEMON_PIDS+=($!)
  fi
done < <(jq -c '.[]' /etc/daemons.json)

# Foreground entrypoint
ep_user=$(jq -r '.user' /etc/entrypoint.json)
readarray -t ep_cmd < <(jq -r '.command[]' /etc/entrypoint.json)

ep_uid=$(resolve_uid "$ep_user")
ep_home="/home/$ep_user"
ep_path="$ep_home/.nix-profile/bin:$ep_home/.local/state/nix/profiles/home-manager/home-path/bin"

cd "$ep_home"
exec setpriv --reuid="$ep_uid" --regid="$ep_uid" --init-groups \
  env \
    HOME="$ep_home" \
    USER="$ep_user" \
    PATH="$ep_path:$PATH" \
    OPENCLAW_NIX_MODE="1" \
    OPENCLAW_STATE_DIR="$ep_home/.openclaw" \
    OPENCLAW_CONFIG_PATH="$ep_home/.openclaw/openclaw.json" \
  "${ep_cmd[@]}"
