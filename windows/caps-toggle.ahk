#Requires AutoHotkey v2.0
#SingleInstance Force
; ---------------------------------------------------------------------------
; caps-toggle.ahk
;
; 「Caps Lock 2度押し」で WezTerm を表示⇔非表示にトグルする。
;   (Mac の「Raycast + Caps Lock 2度押し」の Windows 版)
;
; どのキーを見張るかは起動時に自動判別する:
;
;   - CapsLock がレジストリの Scancode Map で F13 にリマップ済みのマシン
;     (開発者の PC がこれ。3A -> 64) では、AHK に CapsLock は届かず F13 が来る。
;     → F13 の2度押しを見る。同居する "move cursor.ahk" が "F13 & 〜" を修飾キーに
;       使うため、`~` を付けて信号を素通しし、その機能を壊さない。
;
;   - リマップされていない素のマシン (学生の PC はこちら) では CapsLock がそのまま
;     届く。→ CapsLock の2度押しを見る。`~` を付けず信号を握り潰すので、単押しで
;       大文字ロックが暴発しない (Mac の Caps Lock と同じ感覚になる)。
;
; 判別を自動にしている理由: リマップは HKLM への書き込み + 再起動が要る、マシン
; 全体に効く最も侵襲的な操作なので、配布先にそれを強要したくない。片方に決め打ち
; すると、もう片方のマシンで「2度押ししても何も起きない」という無反応な壊れ方をする。
; ---------------------------------------------------------------------------

global held := false
global lastPress := 0

; CapsLock(3A) -> F13(64) のリマップが入っているか調べる。
; Scancode Map は REG_BINARY で、8バイトのヘッダ + 4バイトのエントリ数 +
; 「変換後(2byte) 変換前(2byte)」の並び + 終端 4バイト、いずれもリトルエンディアン。
; AHK は REG_BINARY を連続した16進文字列で返すので、該当エントリ
; (変換後=6400 / 変換前=3A00) が含まれるかを見れば足りる。
IsCapsRemappedToF13() {
    try {
        map := RegRead('HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout', 'Scancode Map')
    } catch {
        return false        ; 値が無い = リマップ無しの素のマシン
    }
    return InStr(map, '64003A00') > 0
}

; 2度押しの検出本体。押しっぱなしのオートリピートは無視する。
OnTriggerDown(*) {
    global held, lastPress
    if held
        return
    held := true
    now := A_TickCount
    if (now - lastPress <= 300) {   ; 300ms 以内の2度押し
        lastPress := 0
        ToggleTerminal()
    } else {
        lastPress := now
    }
}

OnTriggerUp(*) {
    global held := false
}

if IsCapsRemappedToF13() {
    ; F13 は素通し (~) — move cursor.ahk の F13 修飾を壊さないため。
    Hotkey '~*F13', OnTriggerDown
    Hotkey '~*F13 up', OnTriggerUp
} else {
    ; CapsLock は握り潰す (~ 無し) — 単押しで大文字ロックさせない。
    Hotkey '*CapsLock', OnTriggerDown
    Hotkey '*CapsLock up', OnTriggerUp
    SetCapsLockState 'AlwaysOff'
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
