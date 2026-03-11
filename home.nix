# This is the configuration for the cloud computer that runs your OpenClaw
# gateway. You can install packages, set up your shell, and tweak your
# OpenClaw settings — all from this file.
#
# Hit Ctrl+S (or Cmd+S) to save. The editor checks your syntax and, if
# everything looks good, automatically applies the changes.
#
# OpenClaw settings live under programs.openclaw.config — see the
# nix-openclaw module for all available options:
#   https://github.com/openclaw/nix-openclaw
#
# For everything else (packages, shell, git, etc.) see Home Manager:
#   https://nix-community.github.io/home-manager/options.xhtml
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

  programs.openclaw = {
    enable = true;
    package = pkgs.openclaw-gateway;
    systemd.enable = false;
    config = {
      gateway = {
        mode = "local";
        bind = "lan";
        port = 18789;
        controlUi = {
          dangerouslyAllowHostHeaderOriginFallback = true;
          allowInsecureAuth = true;
        };
      };
    };
  };

  # Force overwrite openclaw.json if it already exists on the persistent volume.
  home.file.".openclaw/openclaw.json".force = true;

  programs.git = {
    enable = true;
  };

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
  };
}
