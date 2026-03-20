{ ... }:
{
  perSystem =
    { pkgs, config, ... }:
    let
      gitTools = pkgs.symlinkJoin {
        name = "git-tools";
        paths = [
          pkgs.git
          pkgs.gh
          config.packages.lazygit
          pkgs.delta
        ];
      };

      editorTools = pkgs.symlinkJoin {
        name = "editor-tools";
        paths = [
          config.packages.hx
          config.packages.opencode
        ];
      };
    in
    {
      packages.git-tools = gitTools;
      packages.editor-tools = editorTools;
    };
}
