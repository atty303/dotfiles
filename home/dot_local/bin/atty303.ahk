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
