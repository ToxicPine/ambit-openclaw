{ pkgs, pkgs-unstable, openclaw-gateway, ... }:

{
  imageName = "openclaw";

  # The openclaw gateway is the foreground entrypoint — it IS the persistent
  # service. No separate daemon entry is needed for it. Add additional
  # background daemons here if your setup requires them (e.g. signal-cli,
  # a local model server, etc.).
  daemons = [
    # { name = "my-daemon"; command = [ "my-daemon" ]; user = "user"; }
  ];

  # The gateway runs in the foreground and serves:
  #   - WebSocket control plane on port 18789
  #   - Control UI / WebChat served from the same port
  #
  # It binds to 0.0.0.0 so Fly.io's proxy can reach it. The fly.toml
  # http_service.internal_port must match this port.
  entrypoint = {
    command = [
      "openclaw"
      "gateway"
      "--port" "18789"
      "--hostname" "0.0.0.0"
    ];
    user = "user";
    port = 18789;
  };

  packages = with pkgs; [
    bashInteractive
    coreutils
    curl
    findutils
    git
    gnugrep
    gnused
    jq
    nix
    nodejs_22
    util-linux
    # openclaw-gateway from github:openclaw/nix-openclaw — the official Nix
    # package, pinned and pre-built via Garnix binary cache.
    openclaw-gateway
  ];
}
