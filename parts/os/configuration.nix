{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

  nix = {
    package = pkgs.nix;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # Boot loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.hostName = "nixos-vm";
  networking.networkmanager.enable = true;

  # Time zone and locale
  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";

  # Users
  users.users.root = {
    initialPassword = "root";
  };

  users.users.nixos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    initialPassword = "root";
  };

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
    git
    gh
    htop
    tmux
    helix
    lazygit
    yazi
    nushell
    bash-language-server
  ];

  # Services
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  services.tailscale.enable = true;

  # Docker
  virtualisation.docker.enable = true;

  # Hyper-V support
  virtualisation.hypervGuest.enable = true;

  # System state version
  system.stateVersion = "25.05";
}