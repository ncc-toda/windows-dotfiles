{ config, lib, ... }:
# ---------------------------------------------------------------------------
# Windows ホスト連携 (WSL 上でのみ作用)
#
# WezTerm 設定の配置と、Caps Lock 2度押しトグル(AutoHotkey)の自動起動登録を
# `home-manager switch` (= make switch) に畳み込む。詳細は windows/README.md。
#
# 注意: WezTerm / AutoHotkey 本体は Windows アプリのため Nix では導入できない
#       (winget 任せ)。このモジュールが行うのは「設定の配置」と「AHK の起動登録」
#       だけで、内部で Windows 側の windows/bootstrap.ps1 を呼び出す。
# ---------------------------------------------------------------------------
let
  winDir = "${config.home.homeDirectory}/dotfiles/windows";
in
{
  home.activation.windowsSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # activation は制限 PATH で走るため、WSL/Windows のツールは絶対パスで叩く。
    PS="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
    WSLPATH="/usr/bin/wslpath"
    BOOT="${winDir}/bootstrap.ps1"

    # WSL + Windows 相互運用が使えて、bootstrap があるときだけ実行する。
    # (純 Linux 機ではこのブロックはまるごとスキップされる)
    if [ -x "$PS" ] && [ -f "$BOOT" ] && [ -e "$WSLPATH" ]; then
      WINBOOT="$("$WSLPATH" -w "$BOOT" 2>/dev/null || true)"
      if [ -n "$WINBOOT" ]; then
        echo "windows: WezTerm 設定配置 + Caps Lock トグル登録 (bootstrap.ps1)"
        # Windows 側の失敗で home-manager switch 全体を止めない。
        $DRY_RUN_CMD "$PS" -NoProfile -ExecutionPolicy Bypass -File "$WINBOOT" \
          || echo "windows: bootstrap.ps1 でエラー (WezTerm/AutoHotkey 未導入の可能性。winget で導入してください)"
      fi
    fi
  '';
}
