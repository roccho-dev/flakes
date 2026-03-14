{ config, pkgs, lib, ... }:

{
  imports = [
    ./modules/packages.nix
  ];

  # Home Manager needs this
  home = {
    username = "nixos";
    homeDirectory = "/home/nixos";
    stateVersion = "25.05";
    packages = with pkgs; [];
    file.".profile".text = ''
      [ -f ~/.profile_ ] && source ~/.profile_
    '';
  };

  programs = {
    home-manager.enable = true;

    # 薄い常備レイヤー: 常時必要な最小限設定
    nix-index.enable = true;

    bash = {
      enable = true;
      initExtra = ''
        if [ -f "$HOME/.config/shell/main.sh" ]; then
          source "$HOME/.config/shell/main.sh"
        fi
      '';
    };

    starship = {
      enable = true;
    };

    # Git configuration management moved to Home Manager
    # OS (.os) provides git binary, Home Manager manages user config
    git = {
      enable = true;
      # Basic structure for user configuration
      # userName and userEmail can be set here or configured per-repo
      # aliases = {};
      # extraConfig = {};
    };
  };


}
