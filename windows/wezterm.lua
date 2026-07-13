-- wezterm.lua — WezTerm 設定 (dotfiles 管理 / Mac・Windows 共用)
--
-- Windows: bootstrap.ps1 が %USERPROFILE%\.wezterm.lua にリンクする。
-- Mac:     ~/.wezterm.lua にこのファイルをリンクすれば同じ設定で使える。
--
-- Caps Lock 2度押しの表示/非表示トグルは AutoHotkey(caps-toggle.ahk) が担当する。
-- WezTerm 側の設定は不要。

local wezterm = require 'wezterm'
local config = wezterm.config_builder()
local triple = wezterm.target_triple

-- 見た目 -------------------------------------------------------------------
config.color_scheme = 'OneHalfDark'
config.font = wezterm.font_with_fallback({
  'MesloLGS Nerd Font',
  'Cascadia Code',
  'JetBrains Mono',
})
config.font_size = 13.0
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = 'RESIZE'
config.window_close_confirmation = 'NeverPrompt'
config.default_cursor_style = 'BlinkingBar'
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
config.window_background_opacity = 0.92
config.scrollback_lines = 10000

-- ペイン/タブ操作 (tmux 風・Leader = Ctrl+A) --------------------------------
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
config.keys = {
  -- 分割: Ctrl+A → |(横) / -(縦)。現ペインのドメイン(WSL)を引き継ぐ。
  { key = '|', mods = 'LEADER|SHIFT',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-', mods = 'LEADER',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },

  -- Vim 風ペイン移動: Ctrl+A → h/j/k/l
  { key = 'h', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'LEADER', action = wezterm.action.ActivatePaneDirection 'Right' },

  -- ペインサイズ変更: Ctrl+A → Shift+h/j/k/l
  { key = 'H', mods = 'LEADER|SHIFT', action = wezterm.action.AdjustPaneSize { 'Left', 5 } },
  { key = 'J', mods = 'LEADER|SHIFT', action = wezterm.action.AdjustPaneSize { 'Down', 5 } },
  { key = 'K', mods = 'LEADER|SHIFT', action = wezterm.action.AdjustPaneSize { 'Up', 5 } },
  { key = 'L', mods = 'LEADER|SHIFT', action = wezterm.action.AdjustPaneSize { 'Right', 5 } },

  -- ペイン: z=最大化トグル / x=閉じる
  { key = 'z', mods = 'LEADER', action = wezterm.action.TogglePaneZoomState },
  { key = 'x', mods = 'LEADER', action = wezterm.action.CloseCurrentPane { confirm = true } },

  -- タブ: c=新規 / n=次 / p=前
  { key = 'c', mods = 'LEADER', action = wezterm.action.SpawnTab 'CurrentPaneDomain' },
  { key = 'n', mods = 'LEADER', action = wezterm.action.ActivateTabRelative(1) },
  { key = 'p', mods = 'LEADER', action = wezterm.action.ActivateTabRelative(-1) },

  -- コマンドパレット
  { key = 'p', mods = 'CTRL|SHIFT', action = wezterm.action.ActivateCommandPalette },
}

-- プラットフォーム別 -------------------------------------------------------
if triple:find('windows') then
  -- Windows では既定で WSL(bash) を開く
  config.default_prog = { 'wsl.exe', '--cd', '~' }
  config.win32_system_backdrop = 'Acrylic'   -- 背景ぼかし(WT の acrylic 相当)
elseif triple:find('darwin') then
  config.macos_window_background_blur = 20
end

return config
