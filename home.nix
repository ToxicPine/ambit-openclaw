{ pkgs, pkgs-unstable, ... }:

{
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  programs.bash = {
    enable = true;
    initExtra = ''[[ "$PWD" == "/" ]] && cd'';
    shellAliases = {
      ll = "ls -la";
      rebuild = "cd ~/.nixcfg && home-manager switch --flake .";
      # Tail the gateway log (openclaw writes to ~/.openclaw/logs/ by default)
      gw-logs = "tail -f ~/.openclaw/logs/gateway.log 2>/dev/null || journalctl --user -u openclaw-gateway -f";
    };
    # Enable Nix mode so openclaw skips auto-install/self-mutation flows.
    sessionVariables = {
      OPENCLAW_NIX_MODE = "1";
      # State and config live on the persistent /data volume (see entrypoint.sh).
      # These are set here as fallbacks; the entrypoint exports them explicitly.
      OPENCLAW_STATE_DIR = "/data/homes/user/.openclaw";
      OPENCLAW_CONFIG_PATH = "/data/homes/user/.openclaw/openclaw.json";
    };
  };

  home.packages = with pkgs; [
    curl
    git
    htop
    jq
    ncurses
    ripgrep
    tmux
    vim
    gh
  ];

  programs.git = {
    enable = true;
  };

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
  };
}
