# Home Manager Configuration

## Setup

### New environment
```bash
git clone <repo> ~/
cd ~/.config/nix
nix build
./result/activate
```

### Apply changes
```bash
cd ~/.config/nix
nix build && ./result/activate
```

## Current Configuration

薄い常備レイヤー: 常時必要な最小限のツールと設定のみを管理

- **Shell**: bash with custom config, starship prompt
- **Essential Tools**: nix-index (command-not-found), nh (Nix helper)
- **Nix LSP/Formatter**: nixd, nixfmt-rfc-style  
- **Shell Tools**: shellcheck (bash linter), shfmt (bash formatter)
- **Architecture**: True multi-platform support (aarch64/x86_64, Linux/Darwin)
  - Each platform generates correct binaries via per-system packages.default
  - No cross-platform binary mismatches
- **Note**: 重い言語SDK（nodejs, python, go, rust等）は各プロジェクトのdevshell/direnvで個別管理

### Clean Architecture
- ✅ 未使用inputs削除済み（依存関係最小化）
- ✅ nix-indexの二重管理解消（programs.nix-index.enableで統一管理）
- ✅ 防御的.profile読み込み（存在チェック付き）
- ✅ 真のマルチプラットフォーム対応（各システムで正しいactivationPackage生成）
- ✅ クロスプラットフォーム一貫性保証（aarch64/x86_64/darwinで適切なバイナリ生成）

## Structure
```
~/.config/nix/
├── flake.nix       # Entry point
├── home.nix        # Main configuration
└── modules/        # Modular configs
    └── packages.nix
```

## Without clone (direct from GitHub)
```bash
# From default branch
nix build github:PorcoRosso85/home#homeConfigurations.nixos.activationPackage
./result/activate

# From specific branch
nix build github:yourusername/yourrepo/<branchName>#homeConfigurations.nixos.activationPackage
./result/activate
```

## Alternative setup (partial clone)
```bash
git init
git remote add origin https://github.com/yourusername/yourrepo.git
git fetch origin <branchName>
git checkout <branchName> -- .config/nix
cd .config/nix
nix build
./result/activate
```