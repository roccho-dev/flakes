local wezterm = require 'wezterm'

-- local function layout_3_horizontal_30_30_40()
-- 水平分割レイアウト定義関数
--   return { direction = 'West', -- 水平分割 children = { { weight = 0.3, -- 30% の割合 action = wezterm.action { SpawnTab = {启动目录 = '.'} }, -- 最初のペイン (必要に応じて調整) }, { direction = 'East', -- 残りの領域をさらに水平分割 weight = 0.7, -- 残り 70% の領域 children = { { weight = 0.3/0.7, -- 30% / 70% = 約 43% (全体の約30%) action = wezterm.action { SpawnTab = {启动目录 = '.'} }, -- 2番目のペイン (必要に応じて調整) }, { weight = 0.4/0.7, -- 40% / 70% = 約 57% (全体の約40%) action = wezterm.action { SpawnTab = {启动目录 = '.'} }, -- 3番目のペイン (必要に応じて調整) }, }, }, }, }
-- end

return {
  -- デフォルトの起動コマンドを設定します。
  default_prog = { 'wsl.exe', '-d', 'nix' },

  -- (オプション) デフォルトのドメイン名を 'WSL' に設定 (必須ではないですが、わかりやすくなります)
  -- default_domain = 'WSL',

  -- leader = { key = 'b', mods = 'CTRL', timeout_milliseconds = 1000 },

  keys = {
    -- tmuxバインディング一覧
    {
      key = '%',
      mods = 'LEADER|SHIFT',
      action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
    },
    -- LEADER + 数字でペインジャンプ
    -- { key = '1', mods = 'LEADER', action = wezterm.action.ActivatePaneByIndex(0) },
    -- { key = '2', mods = 'LEADER', action = wezterm.action.ActivatePaneByIndex(1) },
    -- { key = '3', mods = 'LEADER', action = wezterm.action.ActivatePaneByIndex(2) },

    -- レイアウト保存
    {
      key = 'L',
      mods = 'LEADER|SHIFT',
      action = wezterm.action_callback(function(window, pane)
        window:set_config_overrides({
          default_gui_startup_args = { layout_mode = { Lua = layout_3_horizontal_30_30_40 } },
        })
      end),
      description = 'Apply 3 Horizontal Panes (30:30:40) Layout',
    },
  },
  enable_tab_bar = false,
  font = wezterm.font('HackGen Console NF', {weight="Regular", stretch="Normal", style="Normal"}),
  font_size = 12,
}
