Assume `home-manager` is not installed globally and run it through `nix run`.

```bash
# Switch (GitHub)
nix run nixpkgs#home-manager -- switch --flake "github:roccho-dev/flakes?dir=parts/user#nixos"

# Switch (checked-out repo)
cd /home/nixos/repos/flakes
nix run nixpkgs#home-manager -- switch --flake ./parts/user#nixos
```
