```bash
# Preflight (OS)
nix flake metadata --refresh "github:roccho-dev/flakes?dir=parts/os"
sudo nixos-rebuild build --flake "github:roccho-dev/flakes?dir=parts/os#nixos-vm"

# Preflight (user)
nix flake metadata --refresh "github:roccho-dev/flakes?dir=parts/user"
nix build "github:roccho-dev/flakes?dir=parts/user#homeConfigurations.nixos.activationPackage"

# Verify (OS)
readlink -f /run/current-system
for b in git curl rg jq fzf bat; do command -v "$b"; done
for b in hx tmux nu; do command -v "$b" || true; done
systemctl is-active tailscaled

# Verify (user)
home-manager generations | head -n 5
command -v starship
test -f "$HOME/.config/starship.toml"
```
