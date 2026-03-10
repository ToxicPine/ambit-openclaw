{
  description = "openclaw — Personal AI Gateway with NixOS Home Manager on Fly.io";

  nixConfig = {
    extra-substituters = [ "https://cache.garnix.io" ];
    extra-trusted-public-keys = [
      "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-openclaw.url = "github:openclaw/nix-openclaw/17cb7d4b39a8c152c74a4dd79baaea9370e9c629";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [ inputs.nix-openclaw.overlays.default ];
      };
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};

      users = import ./users.nix;
      sysConfig = import ./system.nix { inherit pkgs; };

      # Daemon command args are either:
      #   path  (./lib/foo.sh) — file baked into store as executable script
      #   string ("my-agent")  — runtime command resolved via PATH
      resolveCommandArg =
        arg:
        if builtins.isPath arg then
          pkgs.writeShellScript (builtins.baseNameOf (toString arg)) (builtins.readFile arg)
        else
          arg;

      collectScriptSources =
        daemons:
        builtins.concatMap (
          daemon:
          builtins.concatMap (
            arg:
            if builtins.isPath arg then
              [
                {
                  name = "lib/${builtins.baseNameOf (toString arg)}";
                  path = arg;
                }
              ]
            else
              [ ]
          ) daemon.command
        ) daemons;

      resolveDaemons =
        daemons:
        builtins.map (
          daemon:
          daemon
          // {
            command = builtins.map resolveCommandArg daemon.command;
          }
        ) daemons;

      mkHome =
        username:
        inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          extraSpecialArgs = { inherit pkgs-unstable; };
          modules = [
            inputs.nix-openclaw.homeManagerModules.openclaw
            ./home.nix
            {
              home.username = username;
              home.homeDirectory = "/home/${username}";
            }
          ]
          ++ (if users.${username} ? home then [ users.${username}.home ] else [ ]);
        };

      homeConfigurations = builtins.mapAttrs (name: _: mkHome name) users;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ system ];

      perSystem =
        { ... }:
        {
          packages.default = import ./lib/image.nix {
            inherit pkgs users;
            imageName = sysConfig.imageName;
            system = sysConfig // {
              daemons = resolveDaemons sysConfig.daemons;
            };
            homeActivationPackages = builtins.mapAttrs (_: hc: hc.activationPackage) homeConfigurations;
            entrypoint = pkgs.writeShellScript "entrypoint" (builtins.readFile ./lib/entrypoint.sh);
            configSources = [
              {
                name = "flake.nix";
                path = ./flake.nix;
              }
              {
                name = "flake.lock";
                path = ./flake.lock;
              }
              {
                name = "home.nix";
                path = ./home.nix;
              }
              {
                name = "system.nix";
                path = ./system.nix;
              }
              {
                name = "users.nix";
                path = ./users.nix;
              }
              {
                name = "lib/image.nix";
                path = ./lib/image.nix;
              }
              {
                name = "lib/entrypoint.sh";
                path = ./lib/entrypoint.sh;
              }
            ]
            ++ collectScriptSources sysConfig.daemons;
          };
        };

      flake = {
        lib = { inherit mkHome; };
        inherit homeConfigurations;
      };
    };
}
