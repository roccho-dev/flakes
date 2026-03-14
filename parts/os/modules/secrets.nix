{ ... }:
{
  # SOPS configuration for secret management
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  # Example: sops-managed secrets (uncomment if needed)
  # sops.secrets."myapp/env" = {
  #   path = "/etc/myapp/.env";
  # };
}
