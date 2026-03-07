{ pkgs, ... }:

{
  imageName = "openclaw";
  userRebuild = false;

  daemons = [
    {
      name = "user-rebuild";
      command = [ ./lib/user-rebuild.sh ];
      user = "*";
    }
    {
      name = "setup-openclaw-skills";
      command = [ ./lib/setup-openclaw-skills.sh ];
      user = "*";
    }
  ];

  entrypoint = {
    command = [
      "openclaw"
      "gateway"
      "--port" "3000"
      "--bind" "lan"
    ];
    user = "user";
    port = 3000;
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
  ];
}
