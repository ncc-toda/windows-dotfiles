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

-- プラットフォーム別 -------------------------------------------------------
if triple:find('windows') then
  -- Windows では既定で WSL(bash) を開く
  config.default_prog = { 'wsl.exe', '--cd', '~' }
  config.win32_system_backdrop = 'Acrylic'   -- 背景ぼかし(WT の acrylic 相当)
elseif triple:find('darwin') then
  config.macos_window_background_blur = 20
end

return config
