#Requires AutoHotkey v2.0
#SingleInstance Force

; --- 全域設定 ---
CoordMode "Mouse", "Screen"

; --- 全域變數 ---
global isExpanded := false
global collapsedHeight := 5, expandedHeight := 800
global guiWidth := 0, guiX := 0, guiY := 0
global myGui, exitBtn, contentListView

; --- 初始化 ---
Main()

Main() {
    global guiWidth, guiX, guiY
    if !DllCall("SetProcessDpiAwarenessContext", "Int", -4)
        DllCall("SetProcessDPIAware")

    res := GetPhysicalScreenResolution()
    screenWidth := res[1]
    guiWidth := screenWidth // 2
    guiX := screenWidth // 4
    guiY := 0

    CreateGui()
    myGui.Show("NA x" guiX " y" guiY " w" guiWidth " h" collapsedHeight)
    SetRoundCorners(myGui.Hwnd, 2)
    WinSetTransparent(128, myGui.Hwnd)

    SetTimer(CheckMouseHover, 50)
}

; --- GUI 控制 ---
CreateGui() {
    global myGui, exitBtn, contentListView, guiWidth
    myGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "RapidCopy")
    myGui.BackColor := "EEEEEF"
    myGui.SetFont("s14", "Microsoft YaHei UI") ; s12 代表 12 號字體
    exitBtn := myGui.Add("Button", "w80 h30 Hidden", "離開")
    exitBtn.OnEvent("Click", (*) => ExitApp())
    contentListView := myGui.Add("ListView", "w" (guiWidth - 40) " h" (expandedHeight - 60) " Hidden -Hdr", ["內容"])
    contentListView.OnEvent("Click", OnListViewClick)
}

Expand() {
    global isExpanded, guiX, guiY, guiWidth, expandedHeight, myGui, exitBtn, contentListView
    if (isExpanded)
        return
    isExpanded := true

    SetTimer(CheckMouseHover, 0) ; 停止偵測滑鼠移入

    exitBtn.Visible := true
    contentListView.Visible := true
    exitBtn.Move(guiWidth - 90, expandedHeight - 40)
    contentListView.Move(20, 20)

    PopulateListView()

    myGui.Show("NA x" guiX " y" guiY " w" guiWidth " h" expandedHeight)
    WinSetTransparent(255, myGui.Hwnd)
    SetRoundCorners(myGui.Hwnd, 10)

    ; **關鍵**：強制啟用 GUI 並在之後開始檢查焦點
    WinActivate(myGui.Hwnd)
    SetTimer(CheckFocusTimer, 100)
}

Collapse() {
    global isExpanded, guiX, guiY, guiWidth, collapsedHeight, myGui, exitBtn, contentListView
    if (!isExpanded)
        return
    isExpanded := false

    SetTimer(CheckFocusTimer, 0) ; 停止偵測焦點
    SetTimer(CheckMouseHover, 50) ; 重新開始偵測滑鼠移入

    exitBtn.Visible := false
    contentListView.Visible := false

    myGui.Show("NA x" guiX " y" guiY " w" guiWidth " h" collapsedHeight)
    WinSetTransparent(128, myGui.Hwnd)
    SetRoundCorners(myGui.Hwnd, 2)
}

; --- 事件與計時器 ---
CheckMouseHover(*) {
    local mx, my
    MouseGetPos(&mx, &my)
    if (mx >= guiX && mx <= guiX + guiWidth && my >= guiY && my <= guiY + collapsedHeight)
        Expand()
}

CheckFocusTimer(*) {
    if !WinActive(myGui.Hwnd)
        Collapse()
}

OnListViewClick(lv, rowNumber) {
    if (rowNumber > 0) {
        A_Clipboard := lv.GetText(rowNumber)
        ToolTip("已複製: " A_Clipboard)
        SetTimer(() => ToolTip(), -1000)
        SetTimer(Collapse, -200)
    }
}

PopulateListView() {
    global contentListView
    filePath := A_ScriptDir "\RapidCopy.txt"
    contentListView.Delete()
    if !FileExist(filePath) {
        contentListView.Add("", "找不到 'RapidCopy.txt'")
        return
    }
    fileContent := FileRead(filePath, "UTF-8")
    if (fileContent = "") {
        contentListView.Add("", "檔案是空的或讀取失敗")
        return
    }
    Loop Parse, fileContent, "`n", "`r" {
        if (A_LoopField != "")
            contentListView.Add("", A_LoopField)
    }
    contentListView.ModifyCol(1, "AutoHdr")
}

; --- 輔助函式 ---
GetPhysicalScreenResolution() {
    hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
    width := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 118)
    height := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 117)
    DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
    return [width, height]
}

SetRoundCorners(hwnd, radius) {
    WinGetPos(,, &width, &height, hwnd)
    rgn := DllCall("CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", width, "Int", height, "Int", radius, "Int", radius, "Ptr")
    DllCall("SetWindowRgn", "Ptr", hwnd, "Ptr", rgn, "Int", true)
}