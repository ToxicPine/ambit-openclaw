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
    nix-openclaw.url = "github:openclaw/nix-openclaw";
  };

  outputs = inputs@{ flake-parts, ... }:
    let
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};
      openclaw-gateway = inputs.nix-openclaw.packages.${system}.openclaw-gateway;

      users = import ./users.nix;
      sysConfig = import ./system.nix { inherit pkgs pkgs-unstable openclaw-gateway; };

      mkHome = username: inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = { inherit pkgs-unstable; };
        modules = [
          ./home.nix
          { home.username = username; home.homeDirectory = "/home/${username}"; }
        ] ++ (if users.${username} ? home then [ users.${username}.home ] else []);
      };

      homeConfigurations = builtins.mapAttrs (name: _: mkHome name) users;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ system ];

      perSystem = { ... }:
        let
          # Auto-discover skills from all bundles under skills/.
          # Convention: skills/<bundle>/skills/<name>/SKILL.md
          # Adding a new submodule under skills/ is sufficient — no manual list needed.
          skillsRoot = ./skills;

          skillSources =
            let
              bundles = builtins.attrNames (builtins.readDir skillsRoot);
              skillsOf = bundle:
                let
                  bundleSkillsDir = skillsRoot + "/${bundle}/skills";
                  names = if builtins.pathExists bundleSkillsDir
                    then builtins.attrNames (builtins.readDir bundleSkillsDir)
                    else [];
                in
                  map (name: {
                    inherit name;
                    path = bundleSkillsDir + "/${name}/SKILL.md";
                  }) names;
            in
              builtins.concatMap skillsOf bundles;
        in
        {
          packages.default = import ./lib/image.nix {
            inherit pkgs users skillSources;
            imageName = sysConfig.imageName;
            system = sysConfig;
            homeActivationPackages = builtins.mapAttrs
              (_: hc: hc.activationPackage) homeConfigurations;
            entrypoint    = pkgs.writeShellScript "entrypoint"    (builtins.readFile ./lib/entrypoint.sh);
            setupSkills   = pkgs.writeShellScript "setup-skills"  (builtins.readFile ./lib/setup-skills.sh);
            configSources = [
              { name = "flake.nix";            path = ./flake.nix; }
              { name = "flake.lock";           path = ./flake.lock; }
              { name = "home.nix";             path = ./home.nix; }
              { name = "system.nix";           path = ./system.nix; }
              { name = "users.nix";            path = ./users.nix; }
              { name = "lib/image.nix";        path = ./lib/image.nix; }
              { name = "lib/entrypoint.sh";    path = ./lib/entrypoint.sh; }
              { name = "lib/setup-skills.sh";  path = ./lib/setup-skills.sh; }
            ];
          };
        };

      flake = {
        lib = { inherit mkHome; };
        inherit homeConfigurations;
      };
    };
}
