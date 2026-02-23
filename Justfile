image := "cardellier/openclaw"
fly_image := "registry.fly.io/clawdy"

build:
    nix build 'git+file:.?submodules=1' --accept-flake-config --print-out-paths

push-dockerhub: build
    nix-shell -p skopeo --run "skopeo copy docker-archive:$(nix build 'git+file:.?submodules=1' --accept-flake-config --print-out-paths) docker://{{image}}:latest"

push-fly: build
    nix-shell -p skopeo --run "skopeo copy --dest-creds x:$(fly auth token) docker-archive:$(nix build 'git+file:.?submodules=1' --accept-flake-config --print-out-paths) docker://{{fly_image}}:latest"

push: push-dockerhub push-fly
