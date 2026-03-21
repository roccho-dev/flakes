Assume `home-manager` is not installed globally and run it through `nix run`.

```bash
# Switch through the root flake (single nixpkgs / single lock)
nix run nixpkgs#home-manager -- switch --flake /home/nixos/repos/flakes#nixos
```
