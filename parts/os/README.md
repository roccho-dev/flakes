```bash
# Remote (GitHub)
sudo nixos-rebuild build  --flake github:roccho-dev/flakes?dir=parts/os#nixos-vm
sudo nixos-rebuild switch --flake github:roccho-dev/flakes?dir=parts/os#nixos-vm
sudo nixos-rebuild switch --flake github:roccho-dev/flakes?dir=parts/os#y-wsl

# Local (checked-out repo)
cd /home/nixos/repos/flakes/parts/os
sudo nixos-rebuild build  --flake .#nixos-vm
sudo nixos-rebuild switch --flake .#nixos-vm
```
