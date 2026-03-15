Use the GitHub flake ref for root rebuilds on `nixos-vm`.

```bash
# Switch
sudo nixos-rebuild switch --flake "github:roccho-dev/flakes?dir=parts/os#nixos-vm"
sudo nixos-rebuild switch --flake "github:roccho-dev/flakes?dir=parts/os#rent"

# Build
sudo nixos-rebuild build --flake "github:roccho-dev/flakes?dir=parts/os#nixos-vm"
```
