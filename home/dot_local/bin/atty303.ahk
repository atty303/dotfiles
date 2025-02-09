;;; configuration
GroupAdd("NoEmacs", "ahk_exe WindowsTerminal.exe")
GroupAdd("NoEmacs", "ahk_class SunAwtFrame") ; JetBrains IDE

;;; main
ProcessSetPriority "High"

;;; キーが単独で押されたときコールバックを実行する
StandaloneHotKey(key, callback) {
    static enabled := false
    
    down() {
        enabled := true
        ; https://github.com/karakaram/alt-ime-ahk/issues/2
        Send("{Blind}{vk07}")
    }
    up() {
        if enabled {
            enabled := false
            If A_PriorKey = key {
                callback()
            }
        }
    }
    Hotkey("~" . key, _ => down())
    Hotkey(key . " Up", _ => up())

    standaloneHook := InputHook("L0V")
    standaloneHook.NotifyNonText := true
    standaloneHook.OnKeyDown := (hook, vk, sc) => enabled := false
    standaloneHook.Start()
}

StandaloneHotKey("LAlt", () => Send("{vk1D}")) ; LAlt単独 -> 無変換
StandaloneHotKey("RAlt", () => Send("{vk1C}")) ; RAlt単独 -> 変換

;;; macOS-like Emacsキーバインド
;;; https://jblevins.org/log/kbd#:~:text=Although%20they%20are%20hidden%20in%20plain%20sight%2C%20it,the%20current%20line%20after%20the%20cursor%20use%20%E2%8C%83K.

emacsEnabled := true
emacsCallback(hook, vk, sc) {
    global emacsEnabled
    emacsEnabled := true
}
emacsHook := InputHook("L0V")
emacsHook.NotifyNonText := true
emacsHook.OnKeyDown := emacsCallback
emacsHook.Start()

#HotIf emacsEnabled && not WinActive("ahk_group NoEmacs")

; Ctrl-qの次の入力はEmacsキーバインドにしない
^q:: global emacsEnabled := false

; navigation
^b::Send "{Left}" ; Ctrl+b: 左へ移動
^f::Send "{Right}" ; Ctrl+f: 右へ移動
!^b::Send "{Ctrl down}{Left}{Ctrl up}" ; Ctrl+Alt+b: 左へ単語移動
!^f::Send "{Ctrl down}{Right}{Ctrl up}" ; Ctrl+Alt+f: 右へ単語移動
^a::Send "{Home}" ; Ctrl+a: 行頭へ移動
^e::Send "{End}" ; Ctrl+e: 行末へ移動
^p::Send "{Up}" ; Ctrl+p: 上へ移動
^n::Send "{Down}" ; Ctrl+n: 下へ移動

; navigation with selecting text
+^b::Send "{Shift down}{Left}{Shift up}" ; Ctrl+b: 左へ移動
+^f::Send "{Shift down}{Right}{Shift up}" ; Ctrl+f: 右へ移動
+!^b::Send "{Shift down}{Ctrl down}{Left}{Ctrl up}{Shift up}" ; Ctrl+Alt+b: 左へ単語移動
+!^f::Send "{Shift down}{Ctrl down}{Right}{Ctrl up}{Shift up}" ; Ctrl+Alt+f: 右へ単語移動
+^a::Send "{Shift down}{Home}{Shift up}" ; Ctrl+a: 行頭へ移動
+^e::Send "{Shift down}{End}{Shift up}" ; Ctrl+e: 行末へ移動
+^p::Send "{Shift down}{Up}{Shift up}" ; Ctrl+p: 上へ移動
+^n::Send "{Shift down}{Down}{Shift up}" ; Ctrl+n: 下へ移動

; 文字削除
^h::Send "{Backspace}" ; Ctrl+h: 左の文字を削除
^d::Send "{Delete}" ; Ctrl+d: カーソル位置の文字を削除
^k::Send "{Shift down}{End}{Shift up}{Delete}" ; Ctrl+k: カーソル位置から行末まで削除

; その他
^v::Send "{PgDn}" ; Ctrl+v: ページダウン
^w::Send "{Ctrl down}x{Ctrl up}" ; Ctrl+w: 単語をカット
!w::Send "{Ctrl down}c{Ctrl up}" ; Alt+w: 単語をコピー
^y::Send "{Ctrl down}v{Ctrl up}" ; Ctrl+y: ペースト
^o::Send "{Enter}{Left}"

#HotIf
