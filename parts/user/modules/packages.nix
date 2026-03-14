{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # 薄い常備レイヤー: 常時必要な最小限のツール
    
    # Nix LSP/formatter（常備）
    nixd
    nixfmt-rfc-style
    
    # 必須CLI補助
    nh  # Nix helper
    # nix-index: programs.nix-index.enableで管理
    
    # Shell開発ツール（常備）
    shellcheck  # bash静的解析
    shfmt       # bashフォーマッター
    
    # 注意: 重い言語SDK(rustup, go)は各プロジェクトのdevshellで管理
    # 注意: bash-language-server, batsは各プロジェクトのdevshellで管理
  ];
}