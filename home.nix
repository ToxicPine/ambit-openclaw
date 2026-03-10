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
        port = 3000;
        controlUi = {
          dangerouslyAllowHostHeaderOriginFallback = true;
        };
      };
    };
  };

  programs.git = {
    enable = true;
  };

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
  };
}
