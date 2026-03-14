```bash
# Remote (GitHub)
home-manager switch --flake github:roccho-dev/flakes?dir=parts/user#nixos
nix run nixpkgs#home-manager -- switch --flake github:roccho-dev/flakes?dir=parts/user#nixos

# Local (checked-out repo)
cd /home/nixos/repos/flakes/parts/user
home-manager switch --flake .#nixos
nix run nixpkgs#home-manager -- switch --flake .#nixos
```
