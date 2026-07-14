#Requires AutoHotkey v2.0
#SingleInstance Force
; ---------------------------------------------------------------------------
; ime-shift.ahk
;
; Mac ライクな IME 切り替えを Windows で再現する。
;   - 左 Shift 単押し  → 英数 (IME OFF)
;   - 右 Shift 単押し  → かな (IME ON)
;   - Shift + 他キー   → 従来どおり Shift 修飾として動く
;
; IME の開閉は「キー送出」ではなく IMM32 API 経由で状態を直接指定する:
;   WM_IME_CONTROL(0x283) + IMC_SETOPENSTATUS(0x006) を、対象ウィンドウの
;   デフォルト IME ウィンドウ(ImmGetDefaultIMEWnd)へ送る。
;   → IME 実装に依存しない。Google 日本語入力 / Microsoft IME / ATOK 共通で効く。
;      (vk16/vk1A = VK_IME_ON/OFF は MS-IME 専用で Google IME は解釈しないため不可)
;   → 「開/閉」を絶対指定できるので、Mac 同様「左は必ず OFF・右は必ず ON」になる
;      (トグルではない。今の状態を気にせず叩ける)。IME 側の設定変更は不要。
;
; 「単押し」の判定: Shift を離した瞬間に A_PriorKey を見て、直前が Shift 自身なら
;   単押し＝IME 切替、別キーなら修飾として使われたとみなし切替しない。{Blind} 付き
;   Down/Up なので大文字入力・範囲選択などの素の Shift 挙動は壊れない。
; ---------------------------------------------------------------------------

; アクティブウィンドウの IME 開閉を直接指定する。state: 1=ON(かな) / 0=OFF(英数)。
ImeSetOpen(state) {
    hwnd := WinExist("A")
    if !hwnd
        return
    imeWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
    if !imeWnd
        return
    ; ハンドルへ直接送る。IME のデフォルトウィンドウは隠しウィンドウなので、
    ; AHK の SendMessage(タイトル検索) では "Target window not found" になる。
    ; DllCall なら DetectHiddenWindows の設定に関係なく HWND へ直接届く。
    ; 0x0283 = WM_IME_CONTROL, 0x0006 = IMC_SETOPENSTATUS, lParam = state(0/1)
    DllCall("user32\SendMessageW", "Ptr", imeWnd, "UInt", 0x0283, "Ptr", 0x0006, "Ptr", state, "Ptr")
}

; --- 左 Shift → 英数 (IME OFF) ---------------------------------------------
*LShift::Send "{Blind}{LShift DownR}"
*LShift up:: {
    Send "{Blind}{LShift Up}"
    if (A_PriorKey = "LShift")     ; 他キーと同時押しでなければ単押し
        ImeSetOpen(0)             ; 英数
}

; --- 右 Shift → かな (IME ON) ----------------------------------------------
*RShift::Send "{Blind}{RShift DownR}"
*RShift up:: {
    Send "{Blind}{RShift Up}"
    if (A_PriorKey = "RShift")
        ImeSetOpen(1)             ; かな
}
