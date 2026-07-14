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
local act = wezterm.action

-- セッション復元プラグイン (resurrect.wezterm) ------------------------------
-- 初回ロード時に GitHub から取得する。オフライン等で取れなくても本体設定が
-- 死なないよう pcall で包み、失敗時は復元機能だけ無効化する。
local ok_resurrect, resurrect = pcall(function()
  return wezterm.plugin.require 'https://github.com/MLFlexer/resurrect.wezterm'
end)
if not ok_resurrect then
  wezterm.log_error 'resurrect.wezterm を読み込めませんでした。セッション復元は無効です。'
  resurrect = nil
end

-- 見た目 -------------------------------------------------------------------
config.color_scheme = 'OneHalfDark'
config.font = wezterm.font_with_fallback({
  'MesloLGS Nerd Font',
  'Cascadia Code',
  'JetBrains Mono',
})
config.font_size = 13.0
config.default_cursor_style = 'BlinkingBar'
config.window_padding = { left = 8, right = 8, top = 6, bottom = 6 }
config.window_close_confirmation = 'NeverPrompt'
config.scrollback_lines = 10000

-- 背景透過 (数値を下げるほど透ける)。ぼかしはプラットフォーム別設定で足す。
config.window_background_opacity = 0.92

-- タブバー: 常時表示 + fancy(GUI 風)。fancy だと右クリックメニューや "+"
-- (新規タブ)ボタンが使え、メニューバー的に操作できる。
config.enable_tab_bar = true
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = false
config.show_new_tab_button_in_tab_bar = true

-- ウィンドウ枠: 最小化/最大化/閉じるボタンをタブバーに統合して表示する
-- (= メニューバー的な上部バー)。リサイズも従来どおり可能。
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'

-- 起動時に最大化 + (あれば)前回セッションを復元する ------------------------
-- resurrect_on_gui_startup は保存状態があれば復元して true を、無ければ(初回等)
-- 何もせず false を返す。戻り値で分岐することで、初回の「窓が開かない」問題も
-- 復元時の二重窓も避けつつ、どちらの経路でも最大化して「画面最大」で出す。
local function maximize_gui(win)
  local gui = win:gui_window()
  if gui then gui:maximize() end
end

wezterm.on('gui-startup', function(cmd)
  local restored = false
  if resurrect then
    restored = resurrect.state_manager.resurrect_on_gui_startup(cmd)
  end
  if restored then
    for _, win in ipairs(wezterm.mux.all_windows()) do
      maximize_gui(win)
    end
  else
    local _, _, window = wezterm.mux.spawn_window(cmd or {})
    maximize_gui(window)
  end
end)

-- resurrect: 定期スナップショット (これを起動時復元が読む) --------------------
if resurrect then
  resurrect.state_manager.periodic_save({
    interval_seconds = 60, -- 短めにして直近のパス/レイアウトを取り逃しにくくする
    save_workspaces = true,
    save_windows = true,
    save_tabs = true,
  })
end

-- ペイン/タブ操作 (tmux 風・Leader = Ctrl+A) --------------------------------
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
config.keys = {
  -- 分割: Ctrl+A → |(横) / -(縦)。現ペインのドメイン(WSL)と cwd を引き継ぐ。
  { key = '|', mods = 'LEADER|SHIFT',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = '-', mods = 'LEADER',
    action = act.SplitVertical { domain = 'CurrentPaneDomain' } },

  -- 分割(iTerm 風・1ストローク): Ctrl+D=左右 / Ctrl+Shift+D=上下。
  -- 注: Ctrl+D を奪うのでシェル終了(EOF)は `exit` か Ctrl+A→x を使う。
  { key = 'd', mods = 'CTRL',
    action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'D', mods = 'CTRL|SHIFT',
    action = act.SplitVertical { domain = 'CurrentPaneDomain' } },

  -- Vim 風ペイン移動: Ctrl+A → h/j/k/l
  { key = 'h', mods = 'LEADER', action = act.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'LEADER', action = act.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'LEADER', action = act.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'LEADER', action = act.ActivatePaneDirection 'Right' },

  -- ペイン移動(作成順で前/次・1ストローク): Ctrl+[ / Ctrl+]
  -- 注: Ctrl+[ は端末的には Esc と同じコード。vim 等で Esc がペイン移動に
  --     化ける場合は mods を 'LEADER' に変えるか別キーへ割り当てる。
  { key = '[', mods = 'CTRL', action = act.ActivatePaneDirection 'Prev' },
  { key = ']', mods = 'CTRL', action = act.ActivatePaneDirection 'Next' },

  -- ペインサイズ変更: Ctrl+A → Shift+h/j/k/l
  { key = 'H', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Left', 5 } },
  { key = 'J', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Down', 5 } },
  { key = 'K', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Up', 5 } },
  { key = 'L', mods = 'LEADER|SHIFT', action = act.AdjustPaneSize { 'Right', 5 } },

  -- ペイン: z=最大化トグル / x=閉じる(確認あり)
  { key = 'z', mods = 'LEADER', action = act.TogglePaneZoomState },
  { key = 'x', mods = 'LEADER', action = act.CloseCurrentPane { confirm = true } },

  -- ペイン削除: Ctrl+W (即削除)。
  -- 注: シェル/readline の Ctrl+W(直前の単語削除)を奪う。単語削除は
  --     Ctrl+Backspace かデフォルト維持したい場合はこの行を消す。
  { key = 'w', mods = 'CTRL', action = act.CloseCurrentPane { confirm = false } },

  -- タブ: 新規 = Ctrl+T / Ctrl+A→c、移動 = Ctrl+A→n/p、番号 = Ctrl+A→1..9
  -- 新規タブは現ペインのドメイン(WSL)を引き継ぐので今開いているパスで開く。
  -- 注: Ctrl+T は readline の文字入れ替え(transpose-chars)を奪う。
  { key = 't', mods = 'CTRL', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'c', mods = 'LEADER', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'n', mods = 'LEADER', action = act.ActivateTabRelative(1) },
  { key = 'p', mods = 'LEADER', action = act.ActivateTabRelative(-1) },

  -- コマンドパレット (メニュー相当の全コマンド検索)
  { key = 'p', mods = 'CTRL|SHIFT', action = act.ActivateCommandPalette },
}

-- タブ番号ジャンプ: Ctrl+A → 1..9
for i = 1, 9 do
  table.insert(config.keys, {
    key = tostring(i), mods = 'LEADER', action = act.ActivateTab(i - 1),
  })
end

-- セッション保存/復元のキー (resurrect 有効時のみ) --------------------------
if resurrect then
  -- 手動保存: Ctrl+A → S
  table.insert(config.keys, {
    key = 'S', mods = 'LEADER|SHIFT',
    action = wezterm.action_callback(function()
      resurrect.state_manager.save_state(resurrect.workspace_state.get_workspace_state())
    end),
  })
  -- 復元(ファジー選択): Ctrl+A → R
  table.insert(config.keys, {
    key = 'r', mods = 'LEADER',
    action = wezterm.action_callback(function(win, pane)
      resurrect.fuzzy_loader.fuzzy_load(win, pane, function(id)
        local kind = string.match(id, '^([^/]+)')
        id = string.match(id, '([^/]+)$')
        id = string.match(id, '(.+)%..+$')
        local opts = {
          relative = true,
          restore_text = true,
          on_pane_restore = resurrect.tab_state.default_on_pane_restore,
        }
        if kind == 'workspace' then
          local state = resurrect.state_manager.load_state(id, 'workspace')
          resurrect.workspace_state.restore_workspace(state, opts)
        elseif kind == 'window' then
          local state = resurrect.state_manager.load_state(id, 'window')
          resurrect.window_state.restore_window(pane:window(), state, opts)
        elseif kind == 'tab' then
          local state = resurrect.state_manager.load_state(id, 'tab')
          resurrect.tab_state.restore_tab(pane:tab(), state, opts)
        end
      end)
    end),
  })
end

-- プラットフォーム別 -------------------------------------------------------
if triple:find('windows') then
  -- WSL ドメインを列挙して既定にする。default_prog で毎回 `--cd ~` を強制する
  -- 代わりにドメイン管理にすることで、分割/新タブ/復元が「その時の cwd」で
  -- 開くようになる (cwd は bash の OSC 7 通知で WezTerm が把握する)。
  local wsl = wezterm.default_wsl_domains()
  for _, dom in ipairs(wsl) do
    dom.default_cwd = '~' -- cwd 不明な最初の起動時のみホームから開く
  end
  config.wsl_domains = wsl
  if wsl[1] then
    config.default_domain = wsl[1].name
  else
    -- WSL ディストロが見つからない場合の保険。
    config.default_prog = { 'wsl.exe', '--cd', '~' }
  end
  config.win32_system_backdrop = 'Acrylic' -- 背景ぼかし(WT の acrylic 相当)
elseif triple:find('darwin') then
  config.macos_window_background_blur = 20
end

return config
