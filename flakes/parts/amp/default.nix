{ inputs, ... }:
{
  perSystem = { system, ... }: {
    packages.amp = inputs.amp.packages.${system}.amp;
  };
}
