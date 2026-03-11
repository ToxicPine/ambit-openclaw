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
    {
      name = "file-editor";
      command = [ "deno" "run" "--allow-read" "--allow-write" "--allow-net" "--allow-run" "--allow-env" "/etc/nixcfg/lib/file-editor.ts" ];
      user = "user";
    }
  ];

  entrypoint = {
    command = [
      "openclaw"
      "gateway"
      "--port" "18789"
      "--bind" "lan"
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
    deno
    nodejs_22
    util-linux
  ];
}
