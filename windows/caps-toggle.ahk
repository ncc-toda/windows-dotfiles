#Requires AutoHotkey v2.0
#SingleInstance Force
; ---------------------------------------------------------------------------
; caps-toggle.ahk
;
; 「CapsLock 2度押し」で WezTerm を表示⇔非表示にトグルする。
;   (Mac の「Raycast + Caps Lock 2度押し」の Windows 版)
;
; 重要: この PC では物理 CapsLock がレジストリの Scancode Map で F13 に
;       リマップされている
;       (HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout\Scancode Map:
;        3A -> 64)。そのため AHK からは CapsLock ではなく F13 として届く。
;       よってここでは「F13 の2度押し」を検出する。
;
; 併存する move cursor.ahk が "F13 & 〜" を修飾キーに使うため、壊さないよう:
;   - ~ を付けて F13 信号を素通しする(move cursor の機能を維持)
;   - 押しっぱなしのオートリピートを2度押しと誤検出しない(held ガード)
; ---------------------------------------------------------------------------

global held := false
global lastPress := 0

~*F13:: {
    global held, lastPress
    if held                        ; 押しっぱなしのオートリピートは無視
        return
    held := true
    now := A_TickCount
    if (now - lastPress <= 300) {  ; 300ms 以内の2度押し
        lastPress := 0
        ToggleTerminal()
    } else {
        lastPress := now
    }
}

~*F13 up:: {
    global held := false
}

ToggleTerminal() {
    WT := "ahk_exe wezterm-gui.exe"
    if !WinExist(WT) {
        LaunchWezTerm()            ; 未起動なら起動して出す
        return
    }
    if WinActive(WT) {
        WinMinimize WT             ; 前面にいる → 引っ込める
    } else {
        WinRestore WT              ; 後ろ/最小化 → せり出して前面へ
        WinActivate WT
    }
}

LaunchWezTerm() {
    try {
        Run "wezterm-gui.exe"      ; PATH にあれば
    } catch {
        Run A_ProgramFiles "\WezTerm\wezterm-gui.exe"   ; 既定インストール先
    }
}
