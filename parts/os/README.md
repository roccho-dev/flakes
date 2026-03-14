# NixOS System Configuration

## Architecture Layers

```
os   : ~/.os/          - 土台と更新（machine essentials）
user : home-manager   - ユーザー配布（.config/.ssh含む）
pj   : ~/feat-*/      - 言語SDK/LSP/ツールチェーン
```

## Entry Points (these are the ONLY commands)

| Layer | Command |
|-------|---------|
| **os + user** | `nixos-rebuild switch --flake ~/.os#<host>` |
| **pj** | `./dev` (in each project directory) |

**These commands are the only allowed entry points.**

## Apply (os + user)

```bash
cd ~/.os
sudo nixos-rebuild switch --flake .#y-wsl
```

## Apply (pj)

```bash
cd ~/feat-*/  # or any project directory
./dev         # nix develop -c bash wrapper
```

**No other entry points are allowed.**

## Staged Verification Process

### 1. Build Configuration
```bash
cd ~/.os
sudo nixos-rebuild build --flake .#y-wsl
```

### 2. Dry Run Activation
```bash
sudo nixos-rebuild dry-activate --flake .#y-wsl
```

### 3. Apply
```bash
sudo nixos-rebuild switch --flake .#y-wsl
```

### 4. Rollback
```bash
sudo nixos-rebuild switch --rollback
```

## Current Configuration

- **Host**: y-wsl
- **Layers**:
  - os: machine essentials (git, fd, rg, hx, curl, etc.)
  - user: home-manager (UX packages: gh, fzf, starship, etc.)
  - pj: devShells per project

## Flake inputs
- nixpkgs (25.05)
- nixpkgs-unstable
- sops-nix
- home-manager

## Migration Notes

- Host-specific configurations in `hosts/y-wsl/`
- Home-manager integrated into os flake